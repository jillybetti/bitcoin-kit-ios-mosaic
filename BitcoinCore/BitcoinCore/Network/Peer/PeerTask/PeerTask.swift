import Foundation

open class PeerTask {
    class TimeoutError: Error {
    }

    public let dateGenerator: () -> Date
    public var lastActiveTime: Double? = nil

    weak public var requester: IPeerTaskRequester?
    weak public var delegate: IPeerTaskDelegate?

    public init(dateGenerator: @escaping () -> Date = Date.init) {
        self.dateGenerator = dateGenerator
    }

    open func start() {
    }

    open func handle(blockHeaders: [BlockHeader]) -> Bool {
        return false
    }

    open func handle(merkleBlock: MerkleBlock) -> Bool {
        return false
    }

    open func handle(transaction: FullTransaction) -> Bool {
        return false
    }

    open func handle(getDataInventoryItem item: InventoryItem) -> Bool {
        return false
    }

    open func handle(items: [InventoryItem]) -> Bool {
        return false
    }

    open func handle(message: IMessage) -> Bool {
        return false
    }

    open func checkTimeout() {
    }

    open func resetTimer() {
        lastActiveTime = dateGenerator().timeIntervalSince1970
    }

}

extension PeerTask: Equatable {

    public static func ==(lhs: PeerTask, rhs: PeerTask) -> Bool {
        switch lhs {
        case let t as GetBlockHashesTask: return t.equalTo(rhs as? GetBlockHashesTask)
        case let t as GetMerkleBlocksTask: return t.equalTo(rhs as? GetMerkleBlocksTask)
        case let t as SendTransactionTask: return t.equalTo(rhs as? SendTransactionTask)
        case let t as RequestTransactionsTask: return t.equalTo(rhs as? RequestTransactionsTask)
        default: return true
        }
    }

}
