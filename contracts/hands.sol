// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./onchain_omaha_game.sol";

contract Hands is ERC721URIStorage, Ownable { 
    uint256 tokenid_count;
    constructor(
        string memory name,
        string  memory symbol,
        address _game_contract_address
    ) ERC721(name, symbol) Ownable(_game_contract_address) {}

    function mint(address sender, string calldata uri) public payable onlyOwner returns(uint256 token_id) { 
        _mint(sender, tokenid_count);
        _setTokenURI(tokenid_count, uri);
        token_id = tokenid_count;
        tokenid_count++;
    }

    function fetch_current_id() public view returns(uint256 tokenId) { 
        return tokenid_count;
    }

    function burn(uint256 token_id) public onlyOwner { 
        _burn(token_id);
    }
}

