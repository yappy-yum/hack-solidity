// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

interface ITSwapPool {
    // Note:
    // get the price of token/WETH
    function getPriceOfOnePoolTokenInWeth() external view returns (uint256);
}
