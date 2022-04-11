// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Utilities} from "../../utils/Utilities.sol";
import {console} from "../../utils/Console.sol";

import {Contract} from "../Contract.sol";
import {WethPricefeedSimulator} from "../WethPricefeedSimulator.sol";

contract ContractTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    uint256 internal WETH_START_PRICE = 3_000 * 10**18; // ETH/USD 3000.000
    Utilities internal utils;

    address payable[] internal users;
    address payable internal alice;
    address payable internal bob;
    address payable internal charlie;

    Contract internal binarySsov;
    WethPricefeedSimulator internal wethPricefeedSimulator;
    Contract.Status public status;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(3);

        alice = users[0];
        bob = users[1];
        charlie = users[2];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");

        // everyone starts with 10 eth
        for (uint256 i; i < 3; i++) {
            vm.deal(users[i], 10 ether);
        }

        wethPricefeedSimulator = new WethPricefeedSimulator(WETH_START_PRICE);
        vm.label(address(binarySsov), "WETH simulator");
        binarySsov = new Contract();
        vm.label(address(binarySsov), "Binary SSOV");
    }

    function testCreateBet() public {
        uint256 betId = binarySsov.createBet(address(wethPricefeedSimulator));
        assertEq(betId, 1);
        assertEq(binarySsov.getBet(1).assetPrice, WETH_START_PRICE);
    }

    function testNonOwnerCannotSettleOngoingEpoch() public {
        assertTrue(false);
    }

    function testCannotSettleOngoingEpoch() public {
        binarySsov.createBet(address(wethPricefeedSimulator));
        vm.warp(5 days);
        vm.expectRevert(abi.encodeWithSignature("EpochIsOngoing()"));
        binarySsov.settleEpoch(1, address(wethPricefeedSimulator));
        assert(binarySsov.status() == Contract.Status.EPOCH_START);
    }

    function testSettleEndedEpoch() public {
        assertTrue(false);
    }

    function testCannotDepositAtEnd() public {
        assertTrue(false);
    }

    function testDepositBull() public {
        assertTrue(false);
    }

    function testDepositBear() public {
        assertTrue(false);
    }

    function testWinnerWithdraw() public {
        assertTrue(false);
    }

    function testLoserWithdraw() public {
        assertTrue(false);
    }

    function testCannotWithdraw() public {
        assertTrue(false);
    }

    function testContract() public {
        assertTrue(false);
    }
}
