// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract Warranty is ERC721URIStorage, AccessControl {
    bytes32 public constant SELLER_ROLE = keccak256("SELLER_ROLE");
    using SafeMath for uint256;
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("Warranty Tokens", "WATT") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    struct warrantyNFT {
        uint256 tokenId;
        string uri;
        address mintedBy;
        address owner;
        address soldBy; // remove this
        uint256 validUntil;
    }
    event NftWarrantyCreated(
        uint256 indexed tokenId,
        string uri,
        address mintedBy,
        address owner,
        address soldBy,
        uint256 validUntil
    );
    mapping(uint256 => warrantyNFT) private _idToNft;
    modifier canMint(address _from) {
        if (
            hasRole(SELLER_ROLE, _from) == true ||
            hasRole(DEFAULT_ADMIN_ROLE, _from) == true
        ) {
            _;
        } else {
            revert("You dont have the rights to create Warranty");
        }
    }

    function createWarranty(
        address _to,
        string memory tokenURI,
        uint256 _minutesValid
    ) public canMint(msg.sender) returns (uint256) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(_to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        uint256 t = block.timestamp + _minutesValid.mul(60);
        _idToNft[newTokenId] = warrantyNFT(
            newTokenId,
            tokenURI,
            msg.sender,
            _to,
            msg.sender,
            t
        );
        emit NftWarrantyCreated(
            newTokenId,
            tokenURI,
            msg.sender,
            _to,
            msg.sender,
            t
        );
        return newTokenId;
    }

    function assignSeller(address _to) public {
        grantRole(SELLER_ROLE, _to);
    }

    function fetchMyNFTs() public view returns (warrantyNFT[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (_idToNft[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        warrantyNFT[] memory items = new warrantyNFT[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (_idToNft[i + 1].owner == msg.sender) {
                uint currentId = i + 1;
                warrantyNFT storage currentItem = _idToNft[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchNFTbyTokenId(uint256 _tokenId)
        public
        view
        returns (warrantyNFT memory)
    {
        warrantyNFT memory Item = _idToNft[_tokenId];
        return Item;
    }

    function fetchNFTsMintedBy(address _by)
        public
        view
        returns (warrantyNFT[] memory)
    {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;

        for (uint i = 0; i < totalItemCount; i++) {
            if (_idToNft[i + 1].mintedBy == _by) {
                itemCount += 1;
            }
        }

        warrantyNFT[] memory items = new warrantyNFT[](itemCount);
        for (uint i = 0; i < totalItemCount; i++) {
            if (_idToNft[i + 1].mintedBy == _by) {
                uint currentId = i + 1;
                warrantyNFT storage currentItem = _idToNft[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function resellWarrantyNft(uint256 _tokenId, address _to) public {
        require(
            _idToNft[_tokenId].owner == msg.sender,
            "Only item owner can perform this operation"
        );
        require(validateNft(_tokenId) == true, "Warranty Expired");
        _idToNft[_tokenId].soldBy = msg.sender;
        _idToNft[_tokenId].owner = _to;
        _transfer(msg.sender, _to, _tokenId);
    }

    function validateNft(uint256 _tokenId) public returns (bool) {
        require(_exists(_tokenId) == true, "Token does not exist");
        uint256 val = _idToNft[_tokenId].validUntil;
        if (block.timestamp >= val) {
            _burn(_tokenId);
            _idToNft[_tokenId].owner = address(0);
            return false;
        } else {
            return true;
        }
    }
}
