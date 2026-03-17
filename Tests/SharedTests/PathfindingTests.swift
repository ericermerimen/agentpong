import Testing
@testable import SpriteEngine
@testable import Shared

@Suite("ZoneManager")
struct ZoneManagerTests {

    @Test("Monitor position is within scene bounds")
    func monitorBounds() {
        let zm = ZoneManager()
        let pos = zm.monitorCenter
        #expect(pos.x >= 0 && pos.x <= zm.sceneWidth)
        #expect(pos.y >= 0 && pos.y <= zm.sceneHeight)
    }

    @Test("Monitor is in upper half of scene (desk area)")
    func monitorInUpperHalf() {
        let zm = ZoneManager()
        #expect(zm.monitorCenter.y > zm.sceneHeight / 2)
    }

    @Test("Walkable area is within scene bounds")
    func walkableBounds() {
        let zm = ZoneManager()
        let area = zm.walkableArea
        #expect(area.minX >= 0)
        #expect(area.minY >= 0)
        #expect(area.maxX <= zm.sceneWidth)
        #expect(area.maxY <= zm.sceneHeight)
    }

    @Test("Dog bed is in lower area of scene")
    func dogBedPosition() {
        let zm = ZoneManager()
        #expect(zm.dogBedPosition.y < zm.sceneHeight / 3)
    }

    @Test("Floor center is within walkable area")
    func floorCenterInWalkable() {
        let zm = ZoneManager()
        let center = zm.floorCenter
        let area = zm.walkableArea
        #expect(area.contains(center))
    }

    @Test("Door position is below scene (off-screen)")
    func doorOffScreen() {
        let zm = ZoneManager()
        #expect(zm.doorPosition.y < 0)
    }
}
