import Foundation

/// Grid position for pathfinding
public struct GridPos: Hashable, Equatable {
    public let x: Int
    public let y: Int

    public init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }

    /// Convert to scene coordinates (center of tile)
    public func toScene(tileSize: CGFloat) -> CGPoint {
        CGPoint(
            x: CGFloat(x) * tileSize + tileSize / 2,
            y: CGFloat(y) * tileSize + tileSize / 2
        )
    }

    /// Create from scene coordinates
    public static func fromScene(_ point: CGPoint, tileSize: CGFloat) -> GridPos {
        GridPos(
            Int(point.x / tileSize),
            Int(point.y / tileSize)
        )
    }

    /// Manhattan distance
    public func distance(to other: GridPos) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }
}

/// BFS pathfinding on a tile grid
public struct Pathfinder {
    /// Grid dimensions
    public let width: Int
    public let height: Int
    /// Blocked tiles (furniture, walls)
    private var blocked: Set<GridPos>

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.blocked = []
    }

    public mutating func setBlocked(_ pos: GridPos) {
        blocked.insert(pos)
    }

    public mutating func setBlocked(_ positions: [GridPos]) {
        for p in positions { blocked.insert(p) }
    }

    public func isBlocked(_ pos: GridPos) -> Bool {
        blocked.contains(pos) || pos.x < 0 || pos.y < 0 || pos.x >= width || pos.y >= height
    }

    /// Find path from start to goal using BFS. Returns array of positions including start and goal.
    /// Returns nil if no path exists.
    public func findPath(from start: GridPos, to goal: GridPos) -> [GridPos]? {
        if start == goal { return [start] }
        if isBlocked(goal) {
            // Try adjacent tiles to the goal
            if let nearGoal = nearestWalkable(to: goal) {
                return findPath(from: start, to: nearGoal)
            }
            return nil
        }

        var queue: [GridPos] = [start]
        var cameFrom: [GridPos: GridPos] = [:]
        var visited: Set<GridPos> = [start]

        while !queue.isEmpty {
            let current = queue.removeFirst()

            if current == goal {
                // Reconstruct path
                var path: [GridPos] = [current]
                var node = current
                while let prev = cameFrom[node] {
                    path.append(prev)
                    node = prev
                }
                return path.reversed()
            }

            // 4-directional neighbors
            let neighbors = [
                GridPos(current.x + 1, current.y),
                GridPos(current.x - 1, current.y),
                GridPos(current.x, current.y + 1),
                GridPos(current.x, current.y - 1),
            ]

            for next in neighbors {
                guard !visited.contains(next), !isBlocked(next) else { continue }
                visited.insert(next)
                cameFrom[next] = current
                queue.append(next)
            }
        }

        return nil  // No path found
    }

    /// Find nearest walkable tile to a blocked position
    private func nearestWalkable(to pos: GridPos) -> GridPos? {
        let candidates = [
            GridPos(pos.x + 1, pos.y),
            GridPos(pos.x - 1, pos.y),
            GridPos(pos.x, pos.y + 1),
            GridPos(pos.x, pos.y - 1),
            GridPos(pos.x + 1, pos.y + 1),
            GridPos(pos.x - 1, pos.y - 1),
            GridPos(pos.x + 1, pos.y - 1),
            GridPos(pos.x - 1, pos.y + 1),
        ]
        return candidates.first { !isBlocked($0) }
    }
}
