import Testing
@testable import SpriteEngine
@testable import Shared

@Suite("Pathfinding")
struct PathfindingTests {

    @Test("Simple path on empty grid")
    func simplePath() {
        let pf = Pathfinder(width: 10, height: 10)
        let path = pf.findPath(from: GridPos(0, 0), to: GridPos(3, 3))
        #expect(path != nil)
        #expect(path?.first == GridPos(0, 0))
        #expect(path?.last == GridPos(3, 3))
        #expect(path?.count == 7)
    }

    @Test("Path to same position")
    func samePosition() {
        let pf = Pathfinder(width: 10, height: 10)
        let path = pf.findPath(from: GridPos(5, 5), to: GridPos(5, 5))
        #expect(path != nil)
        #expect(path?.count == 1)
    }

    @Test("GridPos scene coordinate conversion")
    func sceneConversion() {
        let pos = GridPos(3, 5)
        let scene = pos.toScene(tileSize: 16.0)
        #expect(scene.x == 56.0)
        #expect(scene.y == 88.0)
        let back = GridPos.fromScene(scene, tileSize: 16.0)
        #expect(back == pos)
    }

    @Test("Manhattan distance")
    func distance() {
        #expect(GridPos(0, 0).distance(to: GridPos(3, 4)) == 7)
    }
}

@Suite("ZoneManager")
struct ZoneManagerTests {

    @Test("Desk positions are within scene bounds")
    func deskBounds() {
        let zm = ZoneManager()
        for pos in zm.deskPositions {
            #expect(pos.x >= 0 && pos.x <= zm.sceneWidth)
            #expect(pos.y >= 0 && pos.y <= zm.sceneHeight)
        }
    }

    @Test("Lounge positions are within scene bounds")
    func loungeBounds() {
        let zm = ZoneManager()
        for pos in zm.loungePositions {
            #expect(pos.x >= 0 && pos.x <= zm.sceneWidth)
            #expect(pos.y >= 0 && pos.y <= zm.sceneHeight)
        }
    }

    @Test("Zone assignment is stable for same session ID")
    func stableAssignment() {
        let zm = ZoneManager()
        let id = "test-session-123"
        let desk1 = zm.deskForSession(id)
        let desk2 = zm.deskForSession(id)
        #expect(desk1 == desk2)
    }

    @Test("Target positions for all zones")
    func targetPositions() {
        let zm = ZoneManager()
        let id = "test"
        let desk = zm.targetPosition(zone: .desk, sessionId: id)
        let lounge = zm.targetPosition(zone: .lounge, sessionId: id)
        let debug = zm.targetPosition(zone: .debugStation, sessionId: id)
        let door = zm.targetPosition(zone: .door, sessionId: id)

        // All should be within scene
        for pos in [desk, lounge, debug, door] {
            #expect(pos.x >= 0 && pos.x <= 320)
            #expect(pos.y >= 0 && pos.y <= 320)
        }

        // Debug should be near right side (server rack area)
        #expect(debug.x > 200)
        #expect(debug.y > 100)

        // Door should be near bottom-right (entry/exit point)
        #expect(door.y < 50)
        #expect(door.x > 200)
    }
}
