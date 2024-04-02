// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract FooTest is Test {
    uint256 public mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork(vm.rpcUrl("mainnet"), 16_428_000);
    }

}
