// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "src/TSwapPool.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {

    address LP = makeAddr("LP");
    address swapper = makeAddr("swapper");

    // balance amount in this contract
    int public startingX; // amount of native token
    int public startingY; // amount of weth

    // amount to send/receive
    int public expectedDeltaX; // Delta X - we expect
    int public expectedDeltaY; // Delta Y - we expect

    int public actualDeltaX;   // Delta X - actual
    int public actualDeltaY;   // Delta Y - actual

    ERC20Mock token;
    ERC20Mock weth;
    TSwapPool pool;

    constructor(TSwapPool _pool) {
        pool = _pool;
        token = ERC20Mock(_pool.getPoolToken());
        weth = ERC20Mock(_pool.getWeth());
    }

    /*//////////////////////////////////////////////////////////////
                                  Swap
    //////////////////////////////////////////////////////////////*/    

    function swapTokenForWETH(uint outputWETH) public {
        if (weth.balanceOf(address(pool)) <= pool.getMinimumWethDepositAmount()) {
            return;
        }

        // decide amount of WETH needed to be received
        outputWETH = bound(
            outputWETH, 
            pool.getMinimumWethDepositAmount(), 
            weth.balanceOf(address(pool))
        );
        if (outputWETH == weth.balanceOf(address(pool))) return;

        // calculate the amount of token needed to be swapped (including 3% fees)
        uint inputToken = pool.getInputAmountBasedOnOutput({
            outputAmount: outputWETH,
            inputReserves: token.balanceOf(address(pool)),
            outputReserves: weth.balanceOf(address(pool))
        });
        if (inputToken > type(uint64).max) return;

        // keeping track of balance, to be used for assertion checks
        startingX = int(token.balanceOf(address(pool)));
        startingY = int(weth.balanceOf(address(pool)));
        expectedDeltaX = int(inputToken);
        expectedDeltaY = int(-1) * int(outputWETH); // WETH reduced, therefore negative

        // mint swapper some token to be used for swap
        if (token.balanceOf(swapper) < inputToken) {
            token.mint(
                swapper, 
                inputToken - token.balanceOf(swapper)    
            );
        }

        // start swap
        vm.startPrank(swapper);
        token.approve(address(pool), type(uint).max);
        pool.swapExactOutput({
            inputToken: token,
            outputToken: weth,
            outputAmount: outputWETH,
            deadline: uint64(block.timestamp)
        });
        vm.stopPrank();

        actualDeltaX = int(token.balanceOf(address(pool))) - int(startingX);
        actualDeltaY = int(weth.balanceOf(address(pool))) - int(startingY);

    }

    /*//////////////////////////////////////////////////////////////
                           Provide Liquidity
    //////////////////////////////////////////////////////////////*/    

    // Note
    // Liquidity Provider deposits 
    function deposit(uint depositWETH) public {
        depositWETH = bound(
            depositWETH, 
            pool.getMinimumWethDepositAmount(), 
            type(uint64).max // reasonable weth amount to be deposited
        );

        // Note: 
        // getPoolTokensToDepositBasedOnWeth
        // calculate amount of token needed based on the weth - liquidity
        
        startingX = int(token.balanceOf(address(pool)));
        startingY = int(weth.balanceOf(address(pool)));
        expectedDeltaX = int(pool.getPoolTokensToDepositBasedOnWeth(depositWETH));
        expectedDeltaY = int(depositWETH);
        
        vm.startPrank(LP);

        // preparing liquity Provider
        token.mint(LP, uint(expectedDeltaX));
        weth.mint(LP, uint(expectedDeltaY));
        token.approve(address(pool), type(uint).max);
        weth.approve(address(pool), type(uint).max);

        // deposit
        pool.deposit({
            wethToDeposit: uint(expectedDeltaY),
            minimumLiquidityTokensToMint: 0,
            maximumPoolTokensToDeposit: uint(expectedDeltaX),
            deadline: uint64(block.timestamp)
        }); 
        vm.stopPrank();    

        // checks => delta = current balance - starting balance
        actualDeltaX = int(token.balanceOf(address(pool))) - int(startingX);
        actualDeltaY = int(weth.balanceOf(address(pool))) - int(startingY); 
    }
}