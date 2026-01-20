// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Prizes} from "../../src/Prizes.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

contract PrizesTest is Test {
    // ============================================
    //            STATE VARIABLES
    // ============================================

    Prizes prizes;

    address owner = makeAddr("owner");
    address controller = makeAddr("controller"); // The authorized minter
    address user = makeAddr("user");

    string constant BASE_URI = "ipfs://QmWeapons/";

    // ============================================
    //            EVENTS
    // ============================================
    event ChestAddressUpdated(address indexed newAddress);
    event BaseURIUpdated(string newURI);

    // ============================================
    //            SETUP LOGIC
    // ============================================
    function setUp() public {
        // Deploy as owner
        vm.startPrank(owner);
        prizes = new Prizes(BASE_URI);

        // Link the chest controller
        prizes.setMythicChestAddress(controller);
        vm.stopPrank();
    }

    // ============================================
    //            ADMIN CONFIG TESTS
    // ============================================

    function testSetMythicChestAddress() public {
        address newChest = makeAddr("newChest");

        vm.prank(owner);

        // Expect event
        vm.expectEmit(true, false, false, false);
        emit ChestAddressUpdated(newChest);

        prizes.setMythicChestAddress(newChest);

        assertEq(prizes.mythicChestAddress(), newChest);
    }

    function testRevertsIfUserTriesToSetMythicChestAddress() public {
        vm.prank(user);
        vm.expectRevert();
        prizes.setMythicChestAddress(makeAddr("hack"));
    }

    function testRevertsIfSetMythicChestAddressToZero() public {
        vm.prank(owner);
        vm.expectRevert(Prizes.Prizes__ZeroAddress.selector);
        prizes.setMythicChestAddress(address(0));
    }

    function testSetBaseURI() public {
        string memory newUri = "https://new-api.com/";

        vm.prank(owner);
        // Expect event
        vm.expectEmit(false, false, false, true); // only data checked (the string)
        emit BaseURIUpdated(newUri);

        prizes.setBaseURI(newUri);

        assertEq(prizes.baseMetadataURI(), newUri);
    }

    // ============================================
    //            MINTING TESTS
    // ============================================

    function testMintSuccess() public {
        vm.prank(controller);
        prizes.mint(user, 1, 1); // Mint ID 1 (Valid)
        assertEq(prizes.balanceOf(user, 1), 1);
    }

    function testRevertsIfOwnerTriesToMint() public {
        vm.prank(owner);
        vm.expectRevert(Prizes.Prizes__NotAuthorized.selector);
        prizes.mint(user, 1, 1);
    }

    function testRevertsWhenMintingInvalidId() public {
        vm.prank(controller);
        vm.expectRevert(Prizes.Prizes__InvalidWeaponID.selector);
        prizes.mint(user, 0, 1);
    }

    // ============================================
    //            BATCH MINTING TESTS
    // ============================================

    function testMintBatchIsSuccessful() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 5;
        ids[1] = 16; // Max valid ID

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 10;

        vm.prank(controller);
        prizes.mintBatch(user, ids, amounts, "");

        assertEq(prizes.balanceOf(user, 5), 2);
        assertEq(prizes.balanceOf(user, 16), 10);
    }

    function testRevertsIfUserTriesToMintBatch() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(user);
        vm.expectRevert(Prizes.Prizes__NotAuthorized.selector);
        prizes.mintBatch(user, ids, amounts, "");
    }

    function testRevertsWhenMintBatchAnInvalidId() public {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 5;
        ids[1] = 17; // This one is bad
        ids[2] = 2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1;
        amounts[1] = 1;
        amounts[2] = 1;

        vm.prank(controller);

        // The loop should catch the 17 and revert
        vm.expectRevert(Prizes.Prizes__InvalidWeaponID.selector);
        prizes.mintBatch(user, ids, amounts, "");
    }

    // ============================================
    //            URI & INTERFACE TESTS
    // ============================================

    function testUriFormat() public view {
        string memory expected = "ipfs://QmWeapons/5.json";
        string memory actual = prizes.uri(5);

        assertEq(actual, expected);
    }

    function testSupportsInterface() public view {
        assertTrue(prizes.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(prizes.supportsInterface(type(IERC165).interfaceId));
    }
}
