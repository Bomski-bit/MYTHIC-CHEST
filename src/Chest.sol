// SPDX-License-Identifier: MIT

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//    PROJECT:    Mythic Chest                                                //
//    CONTRACT:   Chest.sol                                                   //
//    AUTHOR:     Ogolo Boma                                                  //
//    DATE:       2026                                                        //
//                                                                            //
//    DESCRIPTION:                                                            //
//    The ERC-1155 "Ticket" required to play the Mythic Chest game.           //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Chest is ERC1155, AccessControl {
    using Strings for uint256;

    //////////////////////////////////////////////////////////////////////////////////////////
    //                             STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Role identifier for accounts allowed to mint new tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice ID 0 is strictly reserved for the Chest
    uint256 public constant CHEST_ID = 0;

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                  FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////

    constructor(string memory _baseURI) ERC1155(_baseURI) {
        // Grant the deployer (you) the DEFAULT_ADMIN_ROLE so you can grant permissions later
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Mints new chests.
     * @dev Only callable by the Controller (or other addresses with MINTER_ROLE).
     * @param to The address to receive the chests.
     * @param id The token ID to mint (only CHEST_ID is valid for now).
     * @param amount The amount of tokens to mint.
     * @param data Additional data with no specified format, sent in call to `to`.
     */
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    /**
     * @notice Burns chests to "open" them.
     * @dev Only callable by the Controller. Bypasses user approval for better UX.
     * @param from The address whose chests will be burned.
     * @param id The token ID to burn (only CHEST_ID is valid for now).
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        _burn(from, id, amount);
    }

    /**
     * @notice Overrides standard URI to force "0.json" instead of Hex string.
     * @param tokenId The token ID to query.
     * @return The token URI string.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), tokenId.toString(), ".json"));
    }

    /**
     * @notice Sets a new base URI for all token types.
     * @dev Only callable by Admin.
     * @param newuri The new base URI string.
     */
    function setURI(string calldata newuri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    /**
     * @notice Supports interface overrides for AccessControl and ERC1155.
     * @param interfaceId The interface ID to check.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
