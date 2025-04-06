pub const Candle = struct {
    exchange: []const u8,
    pair: []const u8,
    timestamp: i64,
    open: f64,
    close: f64,
    high: f64,
    low: f64,
    volume: f64,
};
