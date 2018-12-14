pragma solidity ^0.4.8;

contract SmartMeters {

    modifier onlyIssuer() {                                                     //similar to only owner function
        if ((msg.sender != issuer) || (!issuerSet)) {                           //if message sender is not equal to issuer OR (opposite of)issuerSet
            revert();                                                             //Throw
        }
        _;                                                                      //If false continue
    }

    address public issuer;
    mapping (address => address) public owner;                                  //map address to address ??why map itself to itself??
    bool issuerSet = false;                                                     //set the boolean issuerSet to false

    function changeOwner(address meterAddress, address newOwner) public         //Only allow the issuer to change the address of a meter to a newOwner
        onlyIssuer()
    {
        owner[meterAddress] = newOwner;
    }

    // A function that can be run one time that sets the issuer public key. This
    // would logically belong to the constructor or be a preset value, but then
    // it would not be possible to let Truffle select it from one of the
    // accounts made available by TestRPC, and the account would have to be
    // manually changed in code when testing.
    function setIssuer(address _issuer) public {
        if (!issuerSet) {                                                       //If (opposite of)Issuer set
            issuer = _issuer;                                                   //set issuer to _issuer and update issuerset to true
            issuerSet = true;
        }
    }
}
