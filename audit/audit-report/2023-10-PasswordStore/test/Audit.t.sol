// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {PasswordStore} from "../src/PasswordStore.sol";
import {DeployPasswordStore} from "../script/DeployPasswordStore.s.sol";

contract PasswordStoreTest is Test {
    PasswordStore public passwordStore;
    DeployPasswordStore public deployer;
    address public owner;

    function setUp() public {
        deployer = new DeployPasswordStore();
        passwordStore = deployer.run();
        owner = msg.sender;
    }

    function test_anyone_can_setPassword(
        address _user,
        string calldata _password
    ) public {
        vm.assume(_user != address(0));

        // anyone can set password !!
        vm.prank(_user);
        passwordStore.setPassword(_password);

        // checks that passwords are actually stored
        vm.prank(owner);
        console.log(passwordStore.getPassword());
    }    

}