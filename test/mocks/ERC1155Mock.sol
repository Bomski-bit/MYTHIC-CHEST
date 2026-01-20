// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155Mock is ERC1155 {
    constructor() ERC1155("") {}

    // --- Matches IChest.mint (4 parameters) ---
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external {
        _mint(account, id, amount, data);
    }

    // --- Matches IPrizes.mint (3 parameters) ---
    // Note: We just pass empty bytes "" to the internal _mint to satisfy ERC1155
    function mint(address to, uint256 id, uint256 amount) external {
        _mint(to, id, amount, "");
    }

    // --- Matches IPrizes.mintBatch ---
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external {
        _mintBatch(to, ids, amounts, data);
    }

    // --- Matches IChest.burn ---
    function burn(address account, uint256 id, uint256 amount) external {
        _burn(account, id, amount);
    }
}
