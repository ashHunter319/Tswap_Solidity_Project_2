//SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity ^0.8.20;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {PoolFactory} from "../src/PoolFactory.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

contract PoolFactoryTest  is Test {
    PoolFactory Factory; 
    ERC20Mock TokenA;
    ERC20Mock TokenB;
    ERC20Mock MockWeth;

    function setUp() public {
        MockWeth = new ERC20Mock();
        TokenA = new ERC20Mock();
        TokenB = new ERC20Mock();
        Factory = new PoolFactory(address(MockWeth));


    }

    function testCreatePool() public {
        address poolAddress =  Factory.createPool(address(TokenA));
        assertEq(poolAddress, Factory.getPool(address(TokenA)));
        assertEq(address(TokenA), Factory.getToken(poolAddress));

    }

    function cantCreatePooIfExists() public {
        Factory.createPool(address(TokenA));
        vm.expectRevert(abi.encodeWithSelector(PoolFactory.PoolFactory_PoolAlreadyExsits.selector), address(TokenA));
        Factory.createPool(address(TokenA));

    }

}