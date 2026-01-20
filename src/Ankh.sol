// SPDX-License-Identifier: MIT

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//    PROJECT:    Mythic Chest                                                //
//    CONTRACT:   Ankh.sol                                                    //
//    AUTHOR:     Ogolo Boma                                                  //
//    DATE:       2026                                                        //
//                                                                            //
//    DESCRIPTION:                                                            //
//    The currency token for the Mythic Chest ecosystem.                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Ankh Token
 * @author Ogolo Boma
 * @notice The currency token for the Mythic Chest ecosystem.
 * @dev Implements AccessControl for secure minting rights and ERC20Burnable for deflationary mechanics.
 */
contract Ankh is ERC20, ERC20Burnable, AccessControl {
    //////////////////////////////////////////////////////////////////////////////////////////
    //                              STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Role identifier for accounts allowed to mint new tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    //////////////////////////////////////////////////////////////////////////////////////////
    //                                 FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////
    constructor() ERC20("Ankh", "ANKH") {
        /// @notice Grant the deployer (YOU) the Admin role so you can manage other roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        /// @notice Grant the deployer the Minter role so you can mint initial supply or testing tokens
        _grantRole(MINTER_ROLE, msg.sender);

        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    /**
     * @notice Mints new Ankh tokens.
     * @dev Only callable by addresses with MINTER_ROLE.
     * @param to The address to receive the tokens.
     * @param amount The amount of tokens to mint (in wei).
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
