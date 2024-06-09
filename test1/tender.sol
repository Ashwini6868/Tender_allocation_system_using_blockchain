// SPDX-License-Identifier: MIT
pragma solidity ^0.4.21;

contract TenderFactory {
    address[] public deployedTenders;

    mapping(address => User) public users;

    struct User {
        string username;
        string password;
    }

    event UserRegistered(address indexed user, string username);

    function register(string username, string password) public {
        require(bytes(username).length > 0 && bytes(password).length > 0, "Username and password are required.");
        require(bytes(users[msg.sender].username).length == 0, "User already registered.");

        users[msg.sender] = User(username, password);
        emit UserRegistered(msg.sender, username);
    }

    function login(string username, string password) public view returns (bool) {
        require(bytes(username).length > 0 && bytes(password).length > 0, "Username and password are required.");

        address userAddress = findUserAddress(username);
        if (userAddress != address(0)) {
            return keccak256(abi.encodePacked(users[userAddress].password)) == keccak256(abi.encodePacked(password));
        }
        return false;
    }

    function findUserAddress(string username) private view returns (address) {
        for (uint i = 0; i < deployedTenders.length; i++) {
            if (keccak256(abi.encodePacked(users[deployedTenders[i]].username)) == keccak256(abi.encodePacked(username))) {
                return deployedTenders[i];
            }
        }
        return address(0);
    }

    function createTender(string description) public {
        // require(login(users[msg.sender].username, users[msg.sender].password), "Unauthorized user.");
        address newTender = new Tender(description, msg.sender);
        deployedTenders.push(newTender);
    }

    function getDeployedTenders() public view returns (address[]) {
        return deployedTenders;
    }
}

contract Tender {
    bool public complete;
    string public data;
    address public manager;

    struct Bid {
        address bidder;
        uint bidAmount;
        string bid;
        bool accepted;
        bool rejected;
    }

    Bid[] public bids;
    Bid public winner;
    uint public winIndex;

    event BidPlaced(address bidder, uint amount, string description);
    event BidAccepted(address bidder, uint amount, string description);
    event BidRejected(address bidder, uint amount, string description);
    event TenderFinalized(address winner, uint amount);

    modifier restricted() {
        require(msg.sender == manager);
        _;
    }

    constructor(string description, address creator) public {
        manager = creator;
        data = description;
    }

    function getBidSummary(uint index) public view returns (address, uint, string, bool, bool) {
        Bid storage bid = bids[index];
        return (
            bid.bidder,
            bid.bidAmount,
            bid.bid,
            bid.accepted,
            bid.rejected
        );
    }

    function makeBid(uint bidAmount, string desc) public {
        require(msg.sender != manager);
        require(!complete);

        Bid memory newBid = Bid({
            bidder: msg.sender,
            bidAmount: bidAmount,
            bid: desc,
            accepted: false,
            rejected: false
        });

        bids.push(newBid);

        emit BidPlaced(msg.sender, bidAmount, desc);
    }

    function acceptBid(uint index) public restricted {
        require(!complete);
        require(index < bids.length);

        Bid storage bid = bids[index];
        require(!bid.accepted && !bid.rejected);

        bid.accepted = true;

        emit BidAccepted(bid.bidder, bid.bidAmount, bid.bid);
    }

    function rejectBid(uint index) public restricted {
        require(!complete);
        require(index < bids.length);

        Bid storage bid = bids[index];
        require(!bid.accepted && !bid.rejected);

        bid.rejected = true;

        emit BidRejected(bid.bidder, bid.bidAmount, bid.bid);
    }

    function isBidAccepted(uint index) public view returns (bool) {
        require(index < bids.length);
        return bids[index].accepted;
    }

    function finalizeBid(uint index) public restricted {
        require(!complete);
        require(index < bids.length);

        Bid storage bid = bids[index];
        require(bid.accepted);

        winner = bid;
        winIndex = index;
        msg.sender.transfer(address(this).balance);
        complete = true;

        emit TenderFinalized(winner.bidder, winner.bidAmount);
    }

    function getSummary() public view returns (address, string, uint) {
        return (manager, data, bids.length);
    }

    function getBidCount() public view returns (uint) {
        return bids.length;
    }

    function verify() public view {
        require(msg.sender == manager);
    }

    function verifyManager() public view returns (bool) {
        return (manager == msg.sender);
    }

    function status() public view returns (bool) {
        return complete;
    }

    function getBidStatus(address bidder) public view returns (bool accepted, bool rejected) {
        for (uint i = 0; i < bids.length; i++) {
            if (bids[i].bidder == bidder) {
                return (bids[i].accepted, bids[i].rejected);
            }
        }
        revert("Bid not found for this address.");
    }
}
