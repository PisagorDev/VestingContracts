// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

error AuthorizationError();
error ZeroError();

abstract contract OperatorAccess is Initializable {
    address public operator;

    event OperatorSet(address indexed newOperator);

    modifier onlyOperator() {
        require(msg.sender == operator, "AuthorizationError");
        _;
    }

    function setOperator(address _newOperator) external onlyOperator {
        _setOperator(_newOperator);
    }

    function _setOperator(address _newOperator) internal {
        require(_newOperator != address(0), "ZeroError");
        operator = _newOperator;
        emit OperatorSet(_newOperator);
    }
}
