/**
 * /-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\|/-\
 * |                                     |
 * \ _____    ____                       /
 * -|_   _|  / ___|_      ____ _ _ __    -
 * /  | |____\___ \ \ /\ / / _` | '_ \   \
 * |  | |_____|__) \ V  V / (_| | |_) |  |
 * \  |_|    |____/ \_/\_/ \__,_| .__/   /
 * -                            |_|      -
 * /                                     \
 * |                                     |
 * \-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/|\-/
 */
// SPDX-License-Identifier: GNU General Public License v3.0
pragma solidity 0.8.20;

import { TSwapPool } from "./TSwapPool.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract PoolFactory {
    error PoolFactory__PoolAlreadyExists(address tokenAddress);
    // @audit-info not used
    error PoolFactory__PoolDoesNotExist(address tokenAddress); 

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    // Note:
    // token - any native token
    // pool - pair contract, with token & weth
    mapping(address token => address pool) private s_pools;
    mapping(address pool => address token) private s_tokens;

    address private immutable i_wethToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PoolCreated(address tokenAddress, address poolAddress);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address wethToken) {
        // @audit-info zero address?
        i_wethToken = wethToken;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createPool(address tokenAddress) external returns (address) {
        if (s_pools[tokenAddress] != address(0)) {
            revert PoolFactory__PoolAlreadyExists(tokenAddress);
        }

        // Note token name and symbols
        string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
        // @audit-info should be .symbol()
        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
        
        // Note deploy pool contract
        TSwapPool tPool = new TSwapPool(
                                tokenAddress,          // token address
                                i_wethToken,           // base token address (WETH)
                                liquidityTokenName,    // pool name
                                liquidityTokenSymbol   // pool symbol
                            );
        
        // Note update pool and token address
        s_pools[tokenAddress] = address(tPool);
        s_tokens[address(tPool)] = tokenAddress;

        // Note emit event & return pool address
        emit PoolCreated(tokenAddress, address(tPool));
        return address(tPool);
    }

    /*//////////////////////////////////////////////////////////////
                   EXTERNAL AND PUBLIC VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getPool(address tokenAddress) external view returns (address) {
        return s_pools[tokenAddress];
    }

    function getToken(address pool) external view returns (address) {
        return s_tokens[pool];
    }

    function getWethToken() external view returns (address) {
        return i_wethToken;
    }
}
