// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.23 <0.9.0;

import { Ante } from "../src/Ante.sol";

import { BaseScript } from "./Base.s.sol";

/// @dev See the Solidity Scripting tutorial: https://book.getfoundry.sh/tutorials/solidity-scripting
contract Deploy is BaseScript {
    function run() public broadcast returns (Ante ante) {
        address weth = address(0x1); // Update with the correct address of the WETH contract
        ante = new Ante(weth);
    }
}
