//SPDX-License-Identifier: GLWTPL
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Minter is ERC721Enumerable {

    address private admin;

    address[] private payees;
    uint16[] private amounts;

    uint256 public mintingFee;
    uint256 public mintLimit;

    string private baseURI; 

    mapping(address => bool) public minted;

    constructor(
        address[] memory _payees,
        uint16[] memory _amounts,
        uint256 _mintFee,
        uint256 _mintLimit,
        string memory _base
    ) ERC721("Name","Symbol"){
        admin = msg.sender;

        require(_payees.length != 0,"ERR:NA");//NA => Null Array
        require(_payees.length == _amounts.length,"ER::WS");//WS => Wrong Sizes

        uint16 total = 0;

        for(uint256 i= 0; i < _payees.length;){

            require(_payees[i] != address(0),"ERR:ZPA");//ZA => Zero Payee Address
            require(_amounts[i] != 0, "ERR:ZA");//ZA => Zero Amount

            total += _amounts[i];

            unchecked{
                i++;
            }
        } 

        require(_mintFee != 0,"ERR:ZF");//ZF => Zero Fee
        require(_mintLimit != 0, "ERR:ZL");//ZL => Zero Limit

        require(bytes(_base).length != 0,"ERR:NS");//NS => Null String

        mintingFee = _mintFee;
        mintLimit = _mintLimit;
        
        payees = _payees;
        amounts = _amounts;
    }

    modifier OnlyAdmin {
        require(msg.sender == admin,"ERR:NA");//NA => Not Admin
        _;
    }

    function changeAdmin(address _new) external OnlyAdmin {
        require(_new != address(0),"ERR:ZA");//ZA => Zero Address
        admin = _new;
    }

    function relinquishControl() external OnlyAdmin {
        delete admin;
    }

    function changeMintFee(uint256 _new) external OnlyAdmin {
        require(_new != 0,"ERR:ZV");//ZV => Zero Value
        mintingFee = _new;
    }
 
    function Mint() external payable {

        uint256 valueSent = msg.value;

        require(valueSent == mintingFee,"ERR:WV");//WV => Wrong Value

        require(!minted[msg.sender],"ERR:AM");//AM => Already Minted

        require(totalSupply() + 1 <= mintLimit,"ERR:ML");//ML => Mint Limit

        minted[msg.sender] = true;

        _mint(msg.sender,totalSupply() + 1);

    }

    function tokenURI(uint256 tokenID) public view override returns(string memory){
        return string(abi.encodePacked(baseURI,tokenID,".json"));
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
        tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }
}