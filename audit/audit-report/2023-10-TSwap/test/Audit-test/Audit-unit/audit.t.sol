// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "src/PoolFactory.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract TSwapPoolTest is Test {
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock weth;

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    function setUp() public {
        poolToken = new ERC20Mock();
        weth = new ERC20Mock();
        pool = new TSwapPool(address(poolToken), address(weth), "LTokenA", "LA");

        // prepare weth and token for liquidityProvider
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, 200e18);
        weth.approve(address(pool), type(uint).max);
        poolToken.mint(liquidityProvider, 200e18);
        poolToken.approve(address(pool), type(uint).max);
        vm.stopPrank();

        // prepare weth and token for user
        vm.startPrank(user);
        poolToken.mint(user, 11e18);
        poolToken.approve(address(pool), type(uint).max);
        vm.stopPrank();
    }

    function test_errorneous_fees_calculation() public {
        // provide starting liquidity 
        // -> 1:1 liquidity
        // -> 200 for both weth and token
        vm.startPrank(liquidityProvider);
        console.log("liquidity provider total pooltoken balance: ", poolToken.balanceOf(liquidityProvider));
        console.log("liquidity provider total weth balance: ", weth.balanceOf(liquidityProvider));
        console.log("liquidity provider total shares before deposits: ", pool.balanceOf(liquidityProvider));

        pool.deposit({
            wethToDeposit: 200e18,
            minimumLiquidityTokensToMint: 0,
            maximumPoolTokensToDeposit: 200e18,
            deadline: uint64(block.timestamp)
        });

        console.log("liquidity provider total pooltoken balance before user swap: ", poolToken.balanceOf(liquidityProvider));
        console.log("liquidity provider total weth balance before user swap: ", weth.balanceOf(liquidityProvider));
        console.log("liquidity provider total shares after deposits: ", pool.balanceOf(liquidityProvider));
        vm.stopPrank();

        // user buy (swap) 1 weth using, using his existing pool token
        // currently, user balance has 11 token before swap
        vm.startPrank(user);
        console.log("user total pooltoken balance before purchase: ", poolToken.balanceOf(user));
        console.log("user total weth balance before purchase: ", weth.balanceOf(user));

        pool.swapExactOutput({
            inputToken: poolToken,
            outputToken: weth,
            outputAmount: 1 ether,
            deadline: uint64(block.timestamp)
        });

        // Note: 
        // initial liquidity was 1:1 ...
        // therefore expecting about ~1 pooltoken be paid
        // however, it spent too much that user balance is not below 1 ether
        console.log("user total pooltoken balance after purchase: ", poolToken.balanceOf(user));
        console.log("user total weth balance after purchase: ", weth.balanceOf(user));
        vm.stopPrank();

        // liquidity provider withdraw
        vm.startPrank(liquidityProvider);
        pool.withdraw({
            liquidityTokensToBurn: pool.balanceOf(liquidityProvider),
            minWethToWithdraw: 1,
            minPoolTokensToWithdraw: 1,
            deadline: uint64(block.timestamp)
        });

        // Note:
        // because of these, liquidity provider can rug all funds from the pool ...
        // including those deposited by user.
        console.log("liquidity provider total pooltoken balance after withdraw: ", poolToken.balanceOf(liquidityProvider));
        console.log("liquidity provider total weth balance after withdraw: ", weth.balanceOf(liquidityProvider));
        console.log("liquidity provider total shares after withdraw: ", pool.balanceOf(liquidityProvider));
        vm.stopPrank();
    }

}