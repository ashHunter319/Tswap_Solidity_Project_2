//SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity ^0.8.20;

import {IERC20} from "../lib/forge-std/src/interfaces/IERC20.sol";
import {TswapPool} from "./TswapPool.sol";

contract PoolFactory{

    error PoolFactory_PoolAlreadyExsits(address tokenAddress);

    mapping ( address token => address pool) private s_pools;
    mapping (address pool => address token) private s_tokens;

    event PoolCreated(address tokenAddress, address poolAddress);

    address private immutable i_wethToken;

    constructor (address wethToken){
        i_wethToken = wethToken;
    }


    function createPool(address tokenAddress) external returns(address){
        if(s_pools[tokenAddress] != address(0)){
            revert PoolFactory_PoolAlreadyExsits(tokenAddress);
        }

        string memory liquidityTokenName = string.concat("M-Swap", IERC20(tokenAddress).name()); 
        string memory liquidityTokenSymbol = string.concat("MS", IERC20(tokenAddress).name());
        TswapPool tPool = new TswapPool(tokenAddress, i_wethToken,  liquidityTokenName, liquidityTokenSymbol);
        s_pools[tokenAddress] = address(tPool);
        s_tokens[address(tPool)] =  tokenAddress;
        emit PoolCreated(tokenAddress, address(tPool));
        return address(tPool);
    }

    function getPool(address tokenAddress) public view returns(address){
        return s_pools[tokenAddress];
    }

    function getToken(address tokenAddress) public view returns(address){
       return s_tokens[tokenAddress];
    }

    function getWethToken() public view returns(address){
        return i_wethToken;
    }
}