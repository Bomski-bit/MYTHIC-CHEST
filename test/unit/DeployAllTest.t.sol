// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeployAll} from "../../script/DeployAll.s.sol";
import {Ankh} from "../../src/Ankh.sol";
import {Chest} from "../../src/Chest.sol";
import {Prizes} from "../../src/Prizes.sol";
import {MythicChest} from "../../src/MythicChest.sol";

contract DeployAllTest is Test {
    // ===================================================
    //              STATE VARIABLES
    // ===================================================
    DeployAll deployScript;

    address mockDeployer = makeAddr("mockDeployer");

    // ===================================================
    //              SETUP LOGIC
    // ===================================================
    function setUp() public {
        deployScript = new DeployAll();

        // Set environment variables for the deployment script
        vm.setEnv("DEPLOYER_ADDRESS", vm.toString(mockDeployer));
        vm.setEnv("CHEST_BASE_URI", "ipfs://fake-chest/");
        vm.setEnv("PRIZES_BASE_URI", "ipfs://fake-prizes/");
        vm.setEnv("VRF_COORDINATOR", vm.toString(makeAddr("vrf")));
        vm.setEnv("KEY_HASH", vm.toString(bytes32("fake-hash")));
        vm.setEnv("SUBSCRIPTION_ID", "123");
        vm.setEnv("CALLBACK_GAS_LIMIT", "500000");
        vm.setEnv("CHEST_PRICE", vm.toString(uint256(100 ether)));
    }

    // ===================================================
    //              TEST
    // ===================================================
    function testDeploymentAndLinking() public {
        /// @notice 1. RUN THE DEPLOYMENT SCRIPT
        (Ankh ankh, Chest chest, Prizes prizes, MythicChest controller) = deployScript.run();

        /// @notice 2. VERIFY DEPLOYMENT
        assertTrue(address(ankh) != address(0), "Ankh not deployed");
        assertTrue(address(chest) != address(0), "Chest not deployed");
        assertTrue(address(prizes) != address(0), "Prizes not deployed");
        assertTrue(address(controller) != address(0), "Controller not deployed");

        /// @notice Check ownership/deployer logic
        assertTrue(chest.hasRole(chest.DEFAULT_ADMIN_ROLE(), mockDeployer));

        /// @notice Verify that the Controller has MINTER_ROLE on both Chest and Prizes and that Prizes is linked to the Controller
        assertTrue(chest.hasRole(chest.MINTER_ROLE(), address(controller)), "Controller missing MINTER_ROLE on Chest");
        assertEq(prizes.mythicChestAddress(), address(controller), "Controller not linked to Prizes");

        console.log("All deployment checks passed!");
    }
}
