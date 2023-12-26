// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./OperatorAccess.sol";

abstract contract ModeratorAccess is Initializable, OperatorAccess {
    mapping(address => bool) internal moderator;

    event ModeratorSet(address indexed _moderator, bool status);
    
    modifier onlyModerator() {
        require(moderator[msg.sender] || msg.sender == operator, "AuthorizationError");
        _;
    }

    function setModerator(address _moderator, bool _status) external onlyOperator {
        _setModerator(_moderator, _status);
    }

    function _setModerator(address _moderator, bool _status) internal {
        require(_moderator != address(0), "ZeroError");
        moderator[_moderator] = _status;
        emit ModeratorSet(_moderator, _status);
    }
}
