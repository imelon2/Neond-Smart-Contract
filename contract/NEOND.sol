// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NEOND is Initializable, ERC721Upgradeable, ERC721URIStorageUpgradeable, OwnableUpgradeable, UUPSUpgradeable {

    struct AirDrop {
        address to;
        uint256 tokenId;
        string url;
        bytes32 _type;
    }

    mapping(uint256 => bytes32) private _tokenType;
    

    bytes32 public constant AIRDROP_TYPE = keccak256("AIRDROP_TYPE");
    bytes32 public constant BASIC_TYPE = keccak256("BASIC_TYPE");
    bytes32 public constant PREMIUM_TYPE = keccak256("PREMIUM_TYPE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC721_init("NEOND", "NEOND");
        __ERC721URIStorage_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function safeMint(address to, uint256 tokenId, string memory uri,bytes32 _type)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _setType(tokenId,_type);
    }

    function _setType(uint256 _tokenId,bytes32 _type) private {
        _tokenType[_tokenId] = _type;
    }
    
    // if result = bytes32(0) is mean No type or invalid token ID
    function typeOf(uint256 tokenId) public view returns(bytes32) {
        return _tokenType[tokenId];
    }

    function airdrop(AirDrop[] calldata _AirDrop) public onlyOwner {
        uint256 len = _AirDrop.length;
        for(uint8 i = 0; i < len; i++) {
            AirDrop calldata AirDropData = _AirDrop[i];
            _safeMint(AirDropData.to, AirDropData.tokenId);
            _setTokenURI(AirDropData.tokenId, AirDropData.url);
            _setType(AirDropData.tokenId,AirDropData._type);
        }
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
