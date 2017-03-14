//
//  transcoder.swift
//  transcode-cli
//
//  Created by tianyi on 13/3/17.
//  Copyright © 2017 tianyi. All rights reserved.
//

import Foundation

class Transcoder {
    var serverOptions: [String: String] = [:]
    var name: String = "preempt-8-core"
    var zone: String = "europe-west1-d"
    var ip: String = "Unassigned"
    
    var serverKeyPath = "/Users/tianyi/.ssh/scaleway/scw"
    
    var moviePath: String = "/some/movie/path"
    var movieName: String = "movie"
    
    var vq: String = "20"
    var preset: String = "medium"
    var denoise: String = "ultralight"
    
    init() {
        // Set up default options
        defaultServerOptions()
    }
    
    func createServer() {
        setServer()
        
        
        let arguments = gcpQuery
        print("Creating GCP server with arguments:")
        print(arguments)
        
        let output = runQuery(path: "/bin/bash", arguments: arguments)
        
        print("\nResponse:\n" + output)
        if output.contains("ERROR") {
            exit(1)
        }
        
        ip = matchLastIP(string: output)
        print("Server IP: " + ip + "\n")
        
        print("Delete server with command:" + "\n" + deleteServerCommand + "\n")
    }
    
    func transferKey() {
        print("Trying to transfer key...")
        let arguments = transferKeyQuery
//        print(arguments)
        
        while (true) {
            let output = runQuery(path: "/usr/bin/scp", arguments: arguments)
            print("response: " + output)
            if (!output.contains("refused")) {
                print("Success!\n")
                break
            }
            sleep(5)
        }
    }
    
    func generateScript() {
        // Write a script to tmp
        /*
         #!/bin/bash
         scp -o StrictHostKeyChecking=no root@tau.tianyi.io:"/path/to/movie" /home/tianyi/movie;
         HandBrakeCLI -i /home/tianyi/movie -o /home/tianyi/output.mp4 -e x264 -q 22 -B 160 --encoder-preset fast -f av_mp4 --hqdn3d=light
         scp -o StrictHostKeyChecking=no -i /home/tianyi/.ssh/id_rsa /home/tianyi/output.mp4 root@tau.tianyi.io:/root/transcodes/$(DESIRED_NAME).mp4
         gcloud compute instances delete $(NAME) --zone=($ZONE) --quiet
         */
        setMovie()
        setEncode()
        
        print("Writing setup.sh to /tmp/setup.sh...")
        
        var file: String = ""
        
//        file += "echo \"kappa\" > \"/home/tianyi/kappa.txt\"; sleep 50; echo \"keepo\" > \"/home/tianyi/keepo.txt\";"
        
        file += "#!/bin/bash" + "\n"
        file += copyMovieCommand + "\n"
        file += transcodeCommand + "\n" 
        file += sendMovieCommand + "\n"
        file += deleteServerCommand + "\n"
        
        do {
            try file.write(to: URL(fileURLWithPath: "/tmp/setup.sh"), atomically: true, encoding: .utf8)
            print("Success!\n")
        } catch {
            print("Write failed!")
            exit(2)
        }
        
        // Set permissions for script
        print("Setting +x to setup.sh")
        let _ = runQuery(path: "/bin/chmod", arguments: ["+x", "/tmp/setup.sh"])
    }
    
    func transferScript() {
        // Transfer the script to server, run it
        print("Transfering setup.sh to server...\n")
        let response = runQuery(path: "/usr/bin/scp", arguments: transferScriptQuery)
        print(response)
    }
    
    func runScript() {
//        ssh root@remoteserver screen -d -m ./script
        print("Running script...")
        let _ = runQuery(path: "/usr/bin/ssh", arguments: runScriptQuery) // response not expected
        
        print("Please wait for the file to be downloaded.")
        print("To check progress:   ssh tianyi@\(ip)    then    screen -r")
        print("Quit screen with Ctrl-A Ctrl-D\n")
        
        print("To grab file:    \(getMovieCommand)\n")
        
        print("To delete server:    \(deleteServerCommand)\n")
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    // MARK: - Helper functions
    func input() -> String {
        return (readLine()!).trimmingCharacters(in: CharacterSet.whitespaces)
    }
    
    func defaultServerOptions() {
        serverOptions["project"] = "transcoding-161108"
//        serverOptions["zone"] = "europe-west1-d"
        serverOptions["machine-type"] = "n1-highcpu-8"
        serverOptions["subnet"] = "default"
        serverOptions["metadata"] = "startup-script=add-apt-repository ppa:stebbins/handbrake-releases -y; apt-get update -y; apt-get install handbrake-cli -y"
        serverOptions["no-restart-on-failure"] = ""
        serverOptions["maintenance-policy"] = "TERMINATE"
        serverOptions["preemptible"] = ""
        serverOptions["scopes"] = "392474445904-compute@developer.gserviceaccount.com=https://www.googleapis.com/auth/cloud-platform"
        serverOptions["image"] = "ubuntu-1604-xenial-v20170307"
        serverOptions["image-project"] = "ubuntu-os-cloud"
        serverOptions["boot-disk-size"] = "40"
        serverOptions["boot-disk-type"] = "pd-ssd"
        serverOptions["boot-disk-device-name"] = name
    }
    
    func machineType(core: Int) -> String {
        switch core {
        case 1:
            return "custom-1-1024"
        case 2:
            return "n1-highcpu-2"
        case 4:
            return "n1-highcpu-4"
        case 6:
            return "custom-6-5632"
        case 8:
            return "n1-highcpu-8"
        default:
            return "ERROR! PLEASE RETRY"
        }
    }
    
    func setServer() {
        // Provide some settings for the server!
        print("Setting up server")
        var res: String
        print("Server name(\(name)):")
        res = input()
        
        if res != "" {
            name = res
            serverOptions["boot-disk-device-name"] = name
        }
        
        print("Zone(\(zone)):")
        res = input()
        
        if res != "" {
            zone = res
        }
        
        print("Core number(8)[1/2/4/6/8]:")
        res = input()
        
        if res != "" {
            serverOptions["machine-type"] = machineType(core: Int(res)!)
        }
        
    }
    
    func setMovie() {
        print("Setting up movie:")
        print("Use readlink -f file to get its full path")
        var res: String
        // Get movie path
        print("Movie path:")
        res = input()
        moviePath = res
        
        // Get desired name
        print("Movie name(\(movieName)):")
        res = input()
        if res != "" {
            movieName = res
        }
    }
    
    func setEncode() {
        print("Setting encode options:")
        print("Please use ffmpeg to check that the language options are available. Otherwise, quit. Audio selecting has not been implemented/")
        var res: String
        // video quality
        print("Video quality(\(vq)):")
        res = input()
        if res != "" {
            vq = res
        }
        
        // preset
        print("Preset(\(preset))[veryfast/fast/medium/slow]:")
        res = input()
        if res != "" {
            preset = res
        }
        
        // Denoise
        print("Denoise(\(denoise))[ultralight/light/medium/strong]:")
        res = input()
        if res != "" {
            denoise = res
        }
    }
    
    func runQuery(path: String, arguments: [String]) -> String {
        let task = Process()
        task.launchPath = path
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)!
        return output
    }
    
    func matchLastIP(string: String) -> String {
        let pattern = "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: string, options: [], range: NSRange(location: 0, length: string.characters.count))
        let lastMatch = matches[matches.count-1]
        
        let nsString = string as NSString
        let match = nsString.substring(with: lastMatch.range)
        
        return match as String
    }
    
    var gcpQuery: [String] {
        var query = ["/usr/local/google-cloud-sdk/bin/gcloud", "compute", "instances", "create", "--zone=\(zone)", name]
        for (key, value) in serverOptions {
            query.append("--" + key)
            if (value != "") {
                query.append(value)
            }
        }
        return query
    }
    
    var transferKeyQuery: [String] {
        return ["-o", "StrictHostKeyChecking=no", "-i", "/Users/tianyi/.ssh/id_rsa", serverKeyPath, "tianyi@\(ip):/home/tianyi/.ssh/id_rsa"]
    }
    
    var runScriptQuery: [String] {
        return ["-o", "StrictHostKeyChecking=no", "-i", "/Users/tianyi/.ssh/id_rsa", "tianyi@\(ip)", "/usr/bin/screen", "-d", "-m", "/home/tianyi/setup.sh"]
    }
    
    
    var copyMovieCommand: String {
        return "scp -o StrictHostKeyChecking=no -i /home/tianyi/.ssh/id_rsa " +  "root@tau.tianyi.io:" + "\"" + moviePath + "\" " + "/home/tianyi/movie"
    }
    
    var transcodeCommand: String {
        return "HandBrakeCLI -i /home/tianyi/movie -o /home/tianyi/output.mp4 --audio-lang-list \"eng\" --subtitle-lang-list \"eng\" -e x264 -q \(vq) -Q 4 --encoder-preset \(preset) --hqdn3d=\(denoise)"
    }
    
    var sendMovieCommand: String {
        return "scp -o StrictHostKeyChecking=no -i /home/tianyi/.ssh/id_rsa " + "/home/tianyi/output.mp4 " + "root@tau.tianyi.io:\"/root/transcodes/\(movieName).mp4\""
    }
    
    var deleteServerCommand: String {
        return "gcloud compute instances delete \(name) --zone=\(zone) --quiet"
    }
    
    var transferScriptQuery: [String] {
        return ["-o", "StrictHostKeyChecking=no", "-i", "/Users/tianyi/.ssh/id_rsa", "/tmp/setup.sh", "tianyi@\(ip):/home/tianyi/setup.sh"]
    }
    
    var getMovieCommand: String {
        return "scp root@tau.tianyi.io:\"/root/transcodes/\(movieName)\".mp4 " + "\"~/Movies/\(movieName).mp4\""
    }
}

//extension Array {
//    func join() -> String {
//        var s: String = ""
//        for element in self {
//            s += " " + (element as! String)
//        }
//        return s
//    }
//}
