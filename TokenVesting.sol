// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./ModeratorAccess.sol";

/**
 * @title TokenVesting
 * @dev This contract handles the vesting of ERC20 tokens for a given beneficiary.
 * The vesting schedule is customizable and can be defined by the contract creator.
 * The contract supports initializing multiple vesting schedules and beneficiaries.
 */
contract TokenVesting is Initializable, ModeratorAccess {
    using SafeERC20 for IERC20;

    // Defines the structure of a vesting group.
    struct Group {
        uint64 start;
        uint64 cliff;
        uint64 duration;
        uint64 periodTime;
        uint160 unlockRate;
    }

    // Defines the structure for each user's vesting information.
    struct User {
        uint16 group;
        uint64 lastClaim;
        uint160 tokenAmount;
        uint160 claimedAmount;
    }

    // The ERC20 token used for vesting.
    IERC20 private tokenAddress;

    // Mappings to store user and group data.
    mapping(address => User) private userByAddress;
    mapping(uint16 => Group) private groupByName;

    /**
     * @dev Initializes the TokenVesting contract.
     * This function sets up the initial state of the vesting contract.
     * @param _tokenAddress The ERC20 token address used for vesting.
     * @param _moderators Array of addresses that will have moderator privileges.
     */
    function initialize(address _tokenAddress, address _operator, address[] memory _moderators)
        public
        initializer
    {
        operator = _operator; // Set the operator directly
        for (uint256 i = 0; i < _moderators.length; i++) {
            moderator[_moderators[i]] = true;
            emit ModeratorSet(_moderators[i], true);
        }
        tokenAddress = IERC20(_tokenAddress);
    }

    function getUser(address user) public view returns (User memory) {
        return userByAddress[user];
    }

    function getGroup(uint16 name) public view returns (Group memory) {
        return groupByName[name];
    }

    function getTokenAddress() public view returns (address) {
        return address(tokenAddress);
    }

    function getContractBalance() public view returns (uint160) {
        return uint160(tokenAddress.balanceOf(address(this)));
    }

    function getCurrentTime() internal view virtual returns (uint64) {
        return uint64(block.timestamp);
    }

    function addGroup(
        uint16 _name,
        uint64 _start,
        uint64 _cliff,
        uint64 _duration,
        uint64 _periodTime
    ) external onlyOperator {
        groupByName[_name] = Group({
            start: _start,
            cliff: _cliff,
            duration: _duration,
            periodTime: _periodTime,
            unlockRate: (1e18 * _duration) / _periodTime
        });
    }

    function addGroups(
        uint16[] memory _names,
        uint64[] memory _starts,
        uint64[] memory _cliffs,
        uint64[] memory _durations,
        uint64[] memory _periodTimes
    ) external onlyOperator {
        for (uint256 index = 0; index < _names.length; index++) {
            groupByName[_names[index]] = Group({
                start: _starts[index],
                cliff: _cliffs[index],
                duration: _durations[index],
                periodTime: _periodTimes[index],
                unlockRate: (1e18 * _durations[index]) / _periodTimes[index]
            });
        }
    }

    function addUsers(
        address[] calldata _addresses,
        uint16[] calldata _groups,
        uint160[] calldata _tokenAmounts
    ) external onlyModerator {
        uint160 totalTokenAmount = 0;
        uint64 currentTime = getCurrentTime();

        uint24 length = uint24(_addresses.length);
        require(
            length == _groups.length && length == _tokenAmounts.length,
            "Arrays length mismatch"
        );

        for (uint24 i = 0; i < length; i++) {
            address userAddress = _addresses[i];
            User storage user = userByAddress[userAddress];

            // Bu kontrol, aynı adres için birden fazla giriş olup olmadığını kontrol eder.
            require(user.tokenAmount == 0, "User already added");

            user.group = _groups[i];
            user.tokenAmount = _tokenAmounts[i];
            user.lastClaim = currentTime;
            user.claimedAmount = 0;

            totalTokenAmount += _tokenAmounts[i];
        }

        if (totalTokenAmount > 0) {
            tokenAddress.safeTransferFrom(
                msg.sender,
                address(this),
                totalTokenAmount
            );
        }
    }

    function claimTokens() external {
        User storage user = userByAddress[msg.sender];
        Group memory group = groupByName[user.group];

        uint256 currentTime = getCurrentTime();

        if (currentTime <= group.cliff) {
            revert ZeroError();
        }

        if (currentTime > group.cliff + group.duration) {
            currentTime = group.cliff + group.duration;
        }

        uint256 elapsedTime = user.lastClaim <= group.cliff
            ? (currentTime - group.cliff)
            : (currentTime - user.lastClaim);

        uint256 numberOfPeriods = elapsedTime / group.periodTime;

        uint256 claimableTokens = (user.tokenAmount *
            group.unlockRate *
            numberOfPeriods) / 1e18;

        if (claimableTokens > user.tokenAmount - user.claimedAmount) {
            claimableTokens = user.tokenAmount - user.claimedAmount;
        }

        user.claimedAmount = uint160(user.claimedAmount + claimableTokens);
        user.lastClaim = user.lastClaim <= group.cliff
            ? uint64(group.cliff + (numberOfPeriods * group.periodTime))
            : uint64(user.lastClaim + (numberOfPeriods * group.periodTime));
        tokenAddress.safeTransfer(msg.sender, claimableTokens);
    }

    function getClaimableTokens() public view returns (uint256) {
        User memory user = userByAddress[msg.sender];
        Group memory group = groupByName[user.group];

        uint256 currentTime = getCurrentTime();

        if (currentTime <= group.start + group.cliff) {
            return 0;
        }

        if (currentTime > group.start + group.cliff + group.duration) {
            currentTime = group.start + group.cliff + group.duration;
        }

        uint256 elapsedTime = user.lastClaim <= group.start + group.cliff
            ? (currentTime - (group.start + group.cliff))
            : (currentTime - user.lastClaim);

        uint256 numberOfPeriods = elapsedTime / group.periodTime;

        uint256 claimableTokens = (user.tokenAmount *
            group.unlockRate *
            numberOfPeriods) / 1e18;

        return claimableTokens;
    }
}
