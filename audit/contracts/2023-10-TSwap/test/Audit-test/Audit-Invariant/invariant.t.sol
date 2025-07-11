// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { PoolFactory } from "src/PoolFactory.sol";
import { TSwapPool } from "src/TSwapPool.sol";
import { Handler } from "./handler.t.sol";

contract Invariant is StdInvariant, Test {

    PoolFactory factory;
    TSwapPool pool;

    ERC20Mock token;
    ERC20Mock weth;

    Handler handler;

    function setUp() public {
        weth = new ERC20Mock();
        token = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(
            factory.createPool(address(token))
        );

        // add initial liquidity
        token.mint(address(this), 100 ether); // token - X
        weth.mint(address(this), 50 ether);   // weth - Y
        token.approve(address(pool), type(uint).max);
        weth.approve(address(pool), type(uint).max);

        // deposit, to initial x and y
        pool.deposit({
            wethToDeposit: 50 ether,
            minimumLiquidityTokensToMint: 50 ether,
            maximumPoolTokensToDeposit: 100 ether,
            deadline: uint64(block.timestamp)
        });

        handler = new Handler(pool);

        bytes4[] memory functionSelectors = new bytes4[](2);
        functionSelectors[0] = Handler.swapTokenForWETH.selector;
        functionSelectors[1] = Handler.deposit.selector;

        targetSelector(
            FuzzSelector({
                addr: address(handler),
                selectors: functionSelectors
            })
        );
        targetContract(address(handler));
    }

    function invariant_check_Delta() public view {
        assertEq(
            handler.actualDeltaX(), 
            handler.expectedDeltaX(),
            "Invariant: Delta X Checks"
        );
        assertEq(
            handler.actualDeltaY(), 
            handler.expectedDeltaY(),
            "Invariant: Delta Y Checks"
        );
    }

}