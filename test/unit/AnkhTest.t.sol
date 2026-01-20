// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Ankh} from "../../src/Ankh.sol";

contract AnkhTest is Test {
    // ============================================
    //            STATE VARIABLES
    // ============================================
    Ankh public ankh;
    address public deployer;
    address public user1;
    address public user2;

    // ============================================
    //            EVENTS
    // ============================================
    event Transfer(address indexed from, address indexed to, uint256 value);

    // ============================================
    //            SETUP LOGIC
    // ============================================
    function setUp() public {
        deployer = address(this); // The test contract acts as the deployer
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy the contract
        ankh = new Ankh();
    }

    // ============================================
    //            CONFIG TESTS
    // ============================================

    function testInitialMetadata() public view {
        assertEq(ankh.name(), "Ankh");
        assertEq(ankh.symbol(), "ANKH");
        assertEq(ankh.decimals(), 18);
    }

    function testInitialSupply() public view {
        // We expect 1,000,000 tokens with 18 decimals
        uint256 expectedSupply = 1_000_000 * 1e18;
        assertEq(ankh.totalSupply(), expectedSupply);

        // The deployer (this contract) should hold the initial supply
        assertEq(ankh.balanceOf(deployer), expectedSupply);
    }

    // ============================================
    //           ACCESS CONTROL TESTS
    // ============================================

    function testDeployerHasRoles() public view {
        // Check if deployer has Admin role
        assertTrue(ankh.hasRole(ankh.DEFAULT_ADMIN_ROLE(), deployer));

        // Check if deployer has Minter role
        assertTrue(ankh.hasRole(ankh.MINTER_ROLE(), deployer));
    }

    function testMinting_Success() public {
        // Deployer (who has role) mints to user1
        uint256 mintAmount = 500 * 1e18;

        ankh.mint(user1, mintAmount);

        assertEq(ankh.balanceOf(user1), mintAmount);
    }

    function testMintingRevertsIfUnauthorized() public {
        // user1 tries to mint tokens to themselves
        // user1 does NOT have the minter role
        vm.startPrank(user1);

        // We expect this next call to revert with an AccessControl error
        bytes4 selector = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
        vm.expectRevert(abi.encodeWithSelector(selector, user1, ankh.MINTER_ROLE()));
        ankh.mint(user1, 100 * 1e18);

        vm.stopPrank();
    }

    function testGrantRoleAndMint() public {
        // Deployer grants MINTER_ROLE to user1
        ankh.grantRole(ankh.MINTER_ROLE(), user1);

        // Now user1 can mint
        vm.startPrank(user1);
        ankh.mint(user2, 50 * 1e18);
        vm.stopPrank();

        assertEq(ankh.balanceOf(user2), 50 * 1e18);
    }

    // ============================================
    //            BURNING TESTS
    // ============================================

    function testBurn() public {
        // Burn 1000 tokens from deployer balance
        uint256 burnAmount = 1000 * 1e18;
        uint256 startBalance = ankh.balanceOf(deployer);

        ankh.burn(burnAmount);

        assertEq(ankh.balanceOf(deployer), startBalance - burnAmount);
        assertEq(ankh.totalSupply(), startBalance - burnAmount);
    }
}
