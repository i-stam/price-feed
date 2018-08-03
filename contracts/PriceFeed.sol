pragma solidity ^0.4.18;

/* import "github.com/oraclize/ethereum-api/oraclizeAPI.sol"; */
import './OraclizeAPI.sol';
import './DateTime.sol';

contract b64 {

    function b64decode(bytes s) internal returns (bytes) {
        byte v1;
        byte v2;
        byte v3;
        byte v4;

        //bytes memory s = bytes(_s);
        uint length = s.length;
        bytes memory result = new bytes(length);

        uint index;

        bytes memory BASE64_DECODE_CHAR = hex"000000000000000000000000000000000000000000000000000000000000000000000000000000000000003e003e003f3435363738393a3b3c3d00000000000000000102030405060708090a0b0c0d0e0f10111213141516171819000000003f001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f30313233";
        //MAP[chr]
        if (sha3(s[length - 2]) == sha3('=')) {
            length -= 2;
        } else if (sha3(s[length - 1]) == sha3('=')) {
            length -= 1;
        }

        uint count = length >> 2 << 2;

        for (uint i = 0; i < count;) {
            v1 = BASE64_DECODE_CHAR[uint(s[i++])];
            v2 = BASE64_DECODE_CHAR[uint(s[i++])];
            v3 = BASE64_DECODE_CHAR[uint(s[i++])];
            v4 = BASE64_DECODE_CHAR[uint(s[i++])];


            result[index++] = (v1 << 2 | v2 >> 4) & 255;
            result[index++] = (v2 << 4 | v3 >> 2) & 255;
            result[index++] = (v3 << 6 | v4) & 255;
        }

       if (length - count == 2) {
            v1 = BASE64_DECODE_CHAR[uint(s[i++])];
            v2 = BASE64_DECODE_CHAR[uint(s[i++])];
            result[index++] = (v1 << 2 | v2 >> 4) & 255;
        }
        else if (length - count == 3) {
            v1 = BASE64_DECODE_CHAR[uint(s[i++])];
            v2 = BASE64_DECODE_CHAR[uint(s[i++])];
            v3 = BASE64_DECODE_CHAR[uint(s[i++])];

            result[index++] = (v1 << 2 | v2 >> 4) & 255;
            result[index++] = (v2 << 4 | v3 >> 2) & 255;
        }

        // set to correct length
        assembly {
            mstore(result, index)
        }

        //debug(result);
        //res = result;
        return result;
    }
}

contract PriceFeed is usingOraclize, b64{

    event LogConstructorInitiated(string nextStep);
    event LogRateUpdated(string price);
    event LogNewOraclizeQuery(string description);

    /* DateTime time = DateTime(msg.sender); */

    mapping (bytes32 => bool) validIDs;
    string public TKNETH;

    bytes cc_pubkey;
    uint last_update_timestamp;

    modifier onlyOraclize {
        require(msg.sender == oraclize_cbAddress());
        _;
    }

    constructor() public payable {
        OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
        oraclize_setProof(proofType_Native);
        cc_pubkey = hex"a0f4f688350018ad1b9785991c0bde5f704b005dc79972b114dbed4a615a983710bfc647ebe5a320daa28771dce6a2d104f5efa2e4a85ba3760b76d46f8571ca";
        // updateRate();
        emit LogConstructorInitiated("Constructor was initiated. Call 'updateRate()' to send the Oraclize Query.");

    }

    /* The native proof is considered valid if the HTTP Date Header has a timestamp
    *  subsequent to the timestamp of execution of the last Oraclize callback,
    *  which is the time when the price data was updated.
    *  This check prevents Oraclize from doing replay attacks on the signed data.
    */
    function isFresh(string _dateHeader) internal constant returns(bool) {
        uint timestamp = DateTime.parseDate(_dateHeader);

        if (timestamp > last_update_timestamp) {
            return true;
        }
        return false;
    }

    function nativeProof_verify(string result, bytes proof, bytes pubkey) private returns (bool) {
          uint sig_len = uint(proof[1]);
          bytes memory sig = new bytes(sig_len);
          sig = copyBytes(proof, 2, sig_len, sig, 0);
          uint headers_len = uint(proof[2+sig_len])*256 + uint(proof[2+sig_len+1]);
          bytes memory headers = new bytes(headers_len);
          headers = copyBytes(proof, 4+sig_len, headers_len, headers, 0);
          bytes memory dateHeader = new bytes(30);
          dateHeader = copyBytes(headers, 5, 30, dateHeader, 0);
          bytes memory digest = new bytes(headers_len-52); //len("digest: SHA-256=")=16
          digest = copyBytes(headers, 52, headers_len-52, digest, 0);
          //Freshness
          bool dateok = isFresh(string(dateHeader));
          if (!dateok) return false;
          //Integrity
          bool digestok = (sha3(sha256(result)) == sha3(b64decode(digest)));
          if (!digestok) return false;
          //Authenticitys
          bool sigok;
          address signer;
          (sigok, signer) = ecrecovery(sha256(headers), sig);
          return (signer == address(sha3(pubkey)));
      }

    function __callback(bytes32 queryId, string result, bytes proof) public onlyOraclize{
        require(validIDs[queryId]);
        if ((proof.length > 0) && (nativeProof_verify(result, proof, cc_pubkey))) {
          TKNETH = result;
          delete validIDs[queryId];
          last_update_timestamp = now;
        }
        else{
          TKNETH = "ERROR";
        }
        emit LogRateUpdated(result);
    }

    function updateRate() public payable{
        if (oraclize_getPrice("URL") > address(this).balance){
            emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        }
        else{
            bytes32 queryId = oraclize_query("URL","https://min-api.cryptocompare.com/data/price?fsym=TKN&tsyms=ETH&sign=true");
            validIDs[queryId] = true;
            emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
        }
    }

}
