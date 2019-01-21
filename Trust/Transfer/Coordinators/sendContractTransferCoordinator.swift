// Copyright DApps Platform Inc. All rights reserved.

import Foundation
import PromiseKit

final class sendContractTransferCoordinator {
    
    private let keystore: Keystore
    let session: WalletSession
    let formatter = EtherNumberFormatter.full
    let confirmType: ConfirmType
    let server: RPCServer
    
    init(
        session: WalletSession,
        keystore: Keystore,
        confirmType: ConfirmType,
        server: RPCServer
        ) {
        self.session = session
        self.keystore = keystore
        self.confirmType = confirmType
        self.server = server
    }

    
    func sendWithABI(res: @escaping Web3.Web3ResponseCompletion<EthereumData>) -> Void {
        
        let web3 = Web3(rpcURL: self.server.rpcURL.absoluteString)
        
        let contractAddress = Web3EthereumAddress(hexString: self.server.addressHexString)
        
        let path = Bundle.main.path(forResource: "contractABI", ofType: "geojson")
        
        let contractJsonABI = try! String(contentsOfFile: path!).data(using: .utf8)!
        
        // You can optionally pass an abiKey param if the actual abi is nested and not the top level element of the json
        let contract = try! web3.eth.Contract(json: contractJsonABI, abiKey: nil, address: contractAddress)
        
        print(contract.methods.count)
        
        // Get balance of some address
        firstly {
            try contract["balanceOf"]!(Web3EthereumAddress(hex: self.server.addressHexString, eip55: true)).call()
            }.done { outputs in
                print(outputs["_balance"] as? BigUInt)
            }.catch { error in
                print(error)
        }
        
        // Send some tokens to another address (locally signing the transaction)
        let myPrivateKey = try! EthereumPrivateKey(hexPrivateKey: "")
        guard let transaction = contract["transfer"]?(contractAddress!.rawAddress, BigUInt(100000)).createTransaction(nonce: 0, from: myPrivateKey.address, value: 0, gas: 150000, gasPrice: EthereumQuantity(quantity: 21.gwei)) else {
            return
        }
        let signedTx = try! transaction.sign(with: myPrivateKey)

        web3.eth.sendRawTransaction(transaction: signedTx, response: res)
    }
    
}
