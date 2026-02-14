import XCTest
import Foundation

final class IntegrationTests: XCTestCase {
    func runExecutable(args: [String]) -> (Int32, String) {
        let process = Process()
        
        // Find the built executable directly instead of using 'swift run'
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        let executablePath = "\(currentPath)/.build/arm64-apple-macosx/debug/risc-emulator"
        
        // Fallback to other possible paths
        var finalPath = executablePath
        if !fileManager.fileExists(atPath: executablePath) {
            // Try x86_64 build
            let x86Path = "\(currentPath)/.build/x86_64-apple-macosx/debug/risc-emulator"
            if fileManager.fileExists(atPath: x86Path) {
                finalPath = x86Path
            } else {
                // Try debug build without arch
                let debugPath = "\(currentPath)/.build/debug/risc-emulator"
                if fileManager.fileExists(atPath: debugPath) {
                    finalPath = debugPath
                }
            }
        }
        
        process.executableURL = URL(fileURLWithPath: finalPath)
        process.arguments = args

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe

        do {
            try process.run()
        } catch {
            return (-1, "failed to run: \(error) (path: \(finalPath))")
        }

        process.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, out)
    }

    func testSysExit() throws {
        let (status, out) = runExecutable(args: ["--test-sys-exit"]) 
        XCTAssertEqual(status, 0, "Process did not exit successfully: \(out)")
        XCTAssertTrue(out.contains("TEST-SYS-EXIT: OK"), "Output did not contain success marker: \(out)")
    }

    func testSysSpawn() throws {
        let (status, out) = runExecutable(args: ["--test-sys-spawn"]) 
        XCTAssertEqual(status, 0, "Process failed: \(out)")
        XCTAssertTrue(out.contains("TEST-SYS-SPAWN: OK"), "Spawn test failed: \(out)")
    }

    func testSysYield() throws {
        let (status, out) = runExecutable(args: ["--test-sys-yield"]) 
        XCTAssertEqual(status, 0, "Process failed: \(out)")
        XCTAssertTrue(out.contains("TEST-SYS-YIELD: OK"), "Yield test failed: \(out)")
    }
}
