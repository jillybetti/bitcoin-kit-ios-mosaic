import Foundation

class GetMerkleBlocksTask: PeerTask {

    private let allowedIdleTime = 60.0
    private var blockHashes: [BlockHash]
    private var pendingMerkleBlocks = [MerkleBlock]()
    private var merkleBlockValidator: IMerkleBlockValidator
    private weak var merkleBlockHandler: IMerkleBlockHandler?

    init(blockHashes: [BlockHash], merkleBlockValidator: IMerkleBlockValidator, merkleBlockHandler: IMerkleBlockHandler, dateGenerator: @escaping () -> Date = Date.init) {
        self.blockHashes = blockHashes
        self.merkleBlockValidator = merkleBlockValidator
        self.merkleBlockHandler = merkleBlockHandler
        super.init(dateGenerator: dateGenerator)
    }

    override func start() {
        let items = blockHashes.map { blockHash in
            InventoryItem(type: InventoryItem.ObjectType.filteredBlockMessage.rawValue, hash: blockHash.headerHash)
        }

        requester?.send(message: GetDataMessage(inventoryItems: items))
        resetTimer()
    }

    override func handle(message: IMessage) throws -> Bool {
        switch message {
        case let merkleBlockMessage as MerkleBlockMessage:
            let merkleBlock = try merkleBlockValidator.merkleBlock(from: merkleBlockMessage)
            return handle(merkleBlock: merkleBlock)
        case let transactionMessage as TransactionMessage:
            return handle(transaction: transactionMessage.transaction)
        default:
            return false
        }
    }

    private func handle(merkleBlock: MerkleBlock) -> Bool {
        guard let blockHash = blockHashes.first(where: { blockHash in blockHash.headerHash == merkleBlock.headerHash }) else {
            return false
        }
        resetTimer()

        merkleBlock.height = blockHash.height > 0 ? blockHash.height : nil

        if merkleBlock.complete {
            handle(completeMerkleBlock: merkleBlock)
        } else {
            pendingMerkleBlocks.append(merkleBlock)
        }

        return true
    }

    private func handle(transaction: FullTransaction) -> Bool {
        if let index = pendingMerkleBlocks.firstIndex(where: { $0.transactionHashes.contains(transaction.header.dataHash) }) {
            resetTimer()

            let block = pendingMerkleBlocks[index]
            block.transactions.append(transaction)

            if block.complete {
                pendingMerkleBlocks.remove(at: index)
                handle(completeMerkleBlock: block)
            }

            return true
        }

        return false
    }

    override func checkTimeout() {
        if let lastActiveTime = lastActiveTime {
            if dateGenerator().timeIntervalSince1970 - lastActiveTime > allowedIdleTime {
                if blockHashes.isEmpty {
                    delegate?.handle(completedTask: self)
                } else {
                    delegate?.handle(failedTask: self, error: TimeoutError())
                }
            }
        }
    }

    private func handle(completeMerkleBlock merkleBlock: MerkleBlock) {
        if let index = blockHashes.firstIndex(where: { $0.headerHash == merkleBlock.headerHash }) {
            blockHashes.remove(at: index)
        }

        do {
            try merkleBlockHandler?.handle(merkleBlock: merkleBlock)
        } catch {
            delegate?.handle(failedTask: self, error: error)
        }

        if blockHashes.isEmpty {
            delegate?.handle(completedTask: self)
        }
    }

    func equalTo(_ task: GetMerkleBlocksTask?) -> Bool {
        guard let task = task else {
            return false
        }

        return blockHashes == task.blockHashes
    }

}
