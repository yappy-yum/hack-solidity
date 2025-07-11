// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IThunderLoan {
    // @audit-info interface unimplemented, or function parameters incorrect
    function repay(address token, uint256 amount) external;
}
