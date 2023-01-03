// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
pragma solidity ^0.8.0;

interface INEOND is IERC721 {
    function typeOf(uint256 tokenId) external view returns(bytes32);
}