// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Chest} from "../../src/Chest.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract ChestTest is Test {
    // ============================================
    //            STATE VARIABLES
    // ============================================
    Chest chest;

    address admin = makeAddr("admin");
    /// @notice Controller will act as the MythicChest contract
    address controller = makeAddr("controller");
    address user = makeAddr("user");

    /// @notice Roles for AccessControl
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    string constant BASE_URI = "ipfs://QmBase/";

    // ============================================
    //            SETUP LOGIC
    // ============================================
    function setUp() public {
        // 1. Deploy as Admin
        vm.startPrank(admin);
        chest = new Chest(BASE_URI);

        // 2. Grant Controller the MINTER_ROLE
        chest.grantRole(MINTER_ROLE, controller);
        vm.stopPrank();
    }

    // ============================================
    //            INITIALIZATION TESTS
    // ============================================

    function testInitialSetup() public view {
        // Check Admin has Admin Role
        assertTrue(chest.hasRole(DEFAULT_ADMIN_ROLE, admin));
        // Check Controller has Minter Role
        assertTrue(chest.hasRole(MINTER_ROLE, controller));
        // Check Random user does NOT have roles
        assertFalse(chest.hasRole(MINTER_ROLE, user));
        // Check Admin does NOT have Minter Role
        assertFalse(chest.hasRole(MINTER_ROLE, admin));
    }

    // ============================================
    //            MINTING TESTS
    // ============================================

    function testMintAsController() public {
        vm.prank(controller);
        chest.mint(user, 0, 5, "");

        assertEq(chest.balanceOf(user, 0), 5);
    }

    function testRevertsIfUserMints() public {
        vm.prank(user);
        vm.expectRevert();
        chest.mint(user, 0, 5, "");
    }

    function testRevertsWithAccessControlIfUserMints() public {
        vm.prank(user);

        // Expect revert with: AccessControlUnauthorizedAccount(account, neededRole)
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user, MINTER_ROLE)
        );
        chest.mint(user, 0, 5, "");
    }

    // ============================================
    //            BURNING TESTS
    // ============================================

    function testBurnAsController() public {
        // 1. Mint first so we have something to burn
        vm.prank(controller);
        chest.mint(user, 0, 10, "");

        // 2. Burn 3
        vm.prank(controller);
        chest.burn(user, 0, 3);

        // 3. Check Balance (10 - 3 = 7)
        assertEq(chest.balanceOf(user, 0), 7);
    }

    function testRevertsIfUserTriesToBurn() public {
        vm.prank(controller);
        chest.mint(user, 0, 10, "");

        vm.prank(user);
        vm.expectRevert();
        chest.burn(user, 0, 3);
    }

    function testRevertsOnInsufficientBalance() public {
        vm.prank(controller);
        chest.mint(user, 0, 2, "");

        vm.prank(controller);
        // Trying to burn 5 when they only have 2
        vm.expectRevert();
        chest.burn(user, 0, 5);
    }

    // ============================================
    //            URI & INTERFACE TESTS
    // ============================================

    function testUriFormat() public view {
        string memory expected = "ipfs://QmBase/0.json";
        string memory actual = chest.uri(0);

        assertEq(actual, expected);
    }

    function testSetUriAsAdmin() public {
        string memory newUri = "https://api.newwebsite.com/";

        vm.prank(admin);
        chest.setURI(newUri);

        string memory actual = chest.uri(0);
        assertEq(actual, "https://api.newwebsite.com/0.json");
    }

    function testRevertsIfUsertriestoSetUri() public {
        vm.prank(user);
        vm.expectRevert();
        chest.setURI("hack");
    }

    function testSupportsInterface() public view {
        // 1. Check ERC1155 support (Crucial for Marketplaces)
        bool isERC1155 = chest.supportsInterface(type(IERC1155).interfaceId);
        assertTrue(isERC1155, "Should support ERC1155");

        // 2. Check AccessControl support (Crucial for tools to see roles)
        bool isAccessControl = chest.supportsInterface(type(IAccessControl).interfaceId);
        assertTrue(isAccessControl, "Should support AccessControl");

        // 3. Check ERC165 support (The standard itself)
        bool isERC165 = chest.supportsInterface(type(IERC165).interfaceId);
        assertTrue(isERC165, "Should support ERC165");

        // 4. Check False Positive (Random nonsense should fail)
        bytes4 invalidId = 0xffffffff;
        bool isInvalid = chest.supportsInterface(invalidId);
        assertFalse(isInvalid, "Should NOT support random interface");
    }
}
