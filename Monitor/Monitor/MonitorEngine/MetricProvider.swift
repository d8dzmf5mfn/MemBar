import Foundation

protocol MetricProvider {
    associatedtype Output

    mutating func sample() -> Output
}

struct AnyMetricProvider<Output>: MetricProvider {
    private var sampleClosure: () -> Output

    init(_ sample: @escaping () -> Output) {
        self.sampleClosure = sample
    }

    mutating func sample() -> Output {
        sampleClosure()
    }
}
