// SPDX-License-Identifier: MIT

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//    PROJECT:    Mythic Chest                                                //
//    CONTRACT:   Prizes.sol                                                  //
//    AUTHOR:     Ogolo Boma                                                  //
//    DATE:       2026                                                        //
//                                                                            //
//    DESCRIPTION:                                                            //
//    ERC1155 contract for managing Mythic Weapons as prizes.                 //
//    Only the linked MythicChest contract can mint these tokens.             //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Prizes is ERC1155, Ownable {
    using Strings for uint256;

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                 ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////

    error Prizes__NotAuthorized();
    error Prizes__InvalidWeaponID();
    error Prizes__ZeroAddress();

    //////////////////////////////////////////////////////////////////////////////////////////
    //                             STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Address of the authorized Mythic Chest contract.
    address public mythicChestAddress;
    /// @notice Base URI for token metadata.
    string public baseMetadataURI;

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                 EVENTS
    //////////////////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Emitted when the Mythic Chest contract address is updated.
     * @param newAddress The new Mythic Chest contract address.
     */
    event ChestAddressUpdated(address indexed newAddress);

    /**
     * @notice Emitted when the base metadata URI is updated.
     * @param newURI The new base metadata URI.
     */
    event BaseURIUpdated(string newURI);

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                  FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////

    constructor(string memory _baseURI) ERC1155("") Ownable(msg.sender) {
        baseMetadataURI = _baseURI;
    }

    /**
     * @notice Link the Mythic Chest contract to this Weapons contract.
     * @dev Run this function AFTER deploying the MythicChest contract.
     * @param _chestAddress The address of the Mythic Chest contract.
     */
    function setMythicChestAddress(address _chestAddress) external onlyOwner {
        if (_chestAddress == address(0)) revert Prizes__ZeroAddress();

        mythicChestAddress = _chestAddress;
        emit ChestAddressUpdated(_chestAddress);
    }

    /**
     * @notice Update the IPFS folder URI if needed.
     * @dev Only callable by the contract owner.
     * @param _newURI The new base URI for metadata.
     */
    function setBaseURI(string calldata _newURI) external onlyOwner {
        baseMetadataURI = _newURI;
        emit BaseURIUpdated(_newURI);
    }

    /**
     * @notice Override supportsInterface to include ERC1155 interface.
     * @param interfaceId The interface identifier, as specified in ERC-165.
     * @return bool True if the contract implements the requested interface.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Mints a specific weapon ID to a user.
     * @dev Can ONLY be called by the MythicChest contract.
     * @param to The address to mint the weapon to.
     * @param id The weapon ID to mint (must be between 1 and 16).
     * @param amount The amount of the weapon to mint.
     */
    function mint(address to, uint256 id, uint256 amount) external {
        if (msg.sender != mythicChestAddress) revert Prizes__NotAuthorized();
        if (id < 1 || id > 16) revert Prizes__InvalidWeaponID();

        _mint(to, id, amount, "");
    }

    /**
     * @notice Mints multiple weapon IDs to a user in a single transaction.
     * @dev Can ONLY be called by the MythicChest contract.
     * @param to The address to mint the weapons to.
     * @param ids An array of weapon IDs to mint (each must be between 1 and 16).
     * @param amounts An array of amounts corresponding to each weapon ID.
     * @param data Additional data with no specified format, sent in call to `to`.
     */
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external {
        if (msg.sender != mythicChestAddress) revert Prizes__NotAuthorized();

        // Ensure ID is strictly between 1 and 16
        for (uint256 i = 0; i < ids.length; ++i) {
            if (ids[i] < 1 || ids[i] > 16) {
                revert Prizes__InvalidWeaponID();
            }
        }

        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @notice Returns the metadata URI for a given token ID.
     * @dev Overrides default ERC1155 to support "1.json" format (Decimal) instead of the standard hexadecimal format.
     * @param _id The token ID to retrieve the URI for.
     * @return string The complete metadata URI for the specified token ID.
     */
    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(baseMetadataURI, _id.toString(), ".json"));
    }
}
