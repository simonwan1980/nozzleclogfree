#! /usr/bin/env python3
# 
#   File:       SMJobBlessUtil.py
# 
#   Contains:   Tool for checking and correcting apps that use SMJobBless.
# 
#   Written by: DTS
# 
#   Copyright:  Copyright (c) 2012 Apple Inc. All Rights Reserved.
# 
#   Disclaimer: IMPORTANT: This Apple software is supplied to you by Apple Inc.
#               ("Apple") in consideration of your agreement to the following
#               terms, and your use, installation, modification or
#               redistribution of this Apple software constitutes acceptance of
#               these terms.  If you do not agree with these terms, please do
#               not use, install, modify or redistribute this Apple software.
# 
#               In consideration of your agreement to abide by the following
#               terms, and subject to these terms, Apple grants you a personal,
#               non-exclusive license, under Apple's copyrights in this
#               original Apple software (the "Apple Software"), to use,
#               reproduce, modify and redistribute the Apple Software, with or
#               without modifications, in source and/or binary forms; provided
#               that if you redistribute the Apple Software in its entirety and
#               without modifications, you must retain this notice and the
#               following text and disclaimers in all such redistributions of
#               the Apple Software. Neither the name, trademarks, service marks
#               or logos of Apple Inc. may be used to endorse or promote
#               products derived from the Apple Software without specific prior
#               written permission from Apple.  Except as expressly stated in
#               this notice, no other rights or licenses, express or implied,
#               are granted by Apple herein, including but not limited to any
#               patent rights that may be infringed by your derivative works or
#               by other works in which the Apple Software may be incorporated.
# 
#               The Apple Software is provided by Apple on an "AS IS" basis. 
#               APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
#               WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT,
#               MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING
#               THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
#               COMBINATION WITH YOUR PRODUCTS.
# 
#               IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT,
#               INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
#               TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#               DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY
#               OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
#               OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
#               OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR
#               OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF
#               SUCH DAMAGE.
# 

import sys
import os
import getopt
import subprocess
import plistlib
import operator
import tempfile
from typing import Dict, List, Optional

# For Python 3 compatibility


class UsageException(Exception):
    """
    Raised when the progam detects a usage issue; the top-level code catches this 
    and prints a usage message.
    """
    pass


class CheckException(Exception):
    """
    Raised when the "check" subcommand detects a problem; the top-level code catches 
    this and prints a nice error message.
    """
    def __init__(self, message: str, path: Optional[str] = None):
        self.message = message
        self.path = path


def checkCodeSignature(programPath: str, programType: str) -> None:
    """Checks the code signature of the referenced program."""

    # Use the codesign tool to check the signature.  The second "-v" is required to enable 
    # verbose mode, which causes codesign to do more checking.  By default it does the minimum 
    # amount of checking ("Is the program properly signed?").  If you enabled verbose mode it 
    # does other sanity checks, which we definitely want.  The specific thing I'd like to 
    # detect is "Does the code satisfy its own designated requirement?" and I need to enable 
    # verbose mode to get that.

    args = [
        # "false", 
        "codesign", 
        "-v", 
        "-v",
        programPath
    ]
    try:
        subprocess.check_call(args, stderr=open("/dev/null"))
    except subprocess.CalledProcessError as e:
        raise CheckException(f"{programType} code signature invalid", programPath)


def readDesignatedRequirement(programPath: str, programType: str) -> str:
    """Returns the designated requirement of the program as a string."""
    args = [
        # "false", 
        "codesign", 
        "-d", 
        "-r", 
        "-", 
        programPath
    ]
    try:
        req = subprocess.check_output(args, stderr=open("/dev/null"))
        # Convert bytes to string in Python 3
        req = req.decode('utf-8')
    except subprocess.CalledProcessError as e:
        raise CheckException(f"{programType} designated requirement unreadable", programPath)

    reqLines = req.splitlines()
    if len(reqLines) != 1 or not req.startswith("designated => "):
        raise CheckException(f"{programType} designated requirement malformed", programPath)
    return reqLines[0][len("designated => "):]


def readInfoPlistFromPath(infoPath: str) -> Dict:
    """Reads an "Info.plist" file from the specified path."""
    try:
        with open(infoPath, 'rb') as fp:
            info = plistlib.load(fp)
        return info
    except Exception as e:
        raise CheckException(f"'Info.plist' not readable: {str(e)}", infoPath)


def readPlistFromToolSection(toolPath: str, segmentName: str, sectionName: str) -> Dict:
    """Reads a dictionary property list from the specified section within the specified executable."""
    
    # Run otool -s to get a hex dump of the section.
    args = [
        "otool", 
        "-s", 
        segmentName, 
        sectionName, 
        toolPath
    ]
    try:
        plistDump = subprocess.check_output(args)
        # Convert bytes to string in Python 3
        plistDump = plistDump.decode('utf-8')
    except subprocess.CalledProcessError as e:
        raise CheckException(f"tool {segmentName} / {sectionName} section unreadable", toolPath)

    # Convert that hex dump to an property list.
    plistLines = plistDump.splitlines()
    if len(plistLines) < 3 or plistLines[1] != f"Contents of ({segmentName},{sectionName}) section":
        raise CheckException(f"tool {segmentName} / {sectionName} section dump malformed (1)", toolPath)

    del plistLines[0:2]

    try:
        bytes = bytearray()
        for line in plistLines:
            # line looks like this:
            # '0000000100000b80\t3c 3f 78 6d 6c 20 76 65 72 73 69 6f 6e 3d 22 31 '
            columns = line.split("\t")
            assert len(columns) == 2
            # Split hex values and convert each to a byte
            for hexStr in columns[1].split():
                # Convert hex string to integer, then to byte
                try:
                    byte = int(hexStr, 16)
                    # If we get a large number, try interpreting it as a 2-digit hex
                    if byte > 255:
                        byte = int(hexStr[-2:], 16)  # Take last 2 chars as hex
                    if byte < 0 or byte > 255:
                        raise ValueError(f"Invalid byte value: {byte} from hex {hexStr}")
                    bytes.append(byte)
                except ValueError as e:
                    raise ValueError(f"Error converting hex {hexStr}: {str(e)}")
        
        # Save to temporary file and read it
        with tempfile.NamedTemporaryFile(delete=False) as temp_file:
            temp_file.write(bytes)
            temp_file.flush()
            try:
                with open(temp_file.name, 'rb') as f:
                    plist = plistlib.load(f)
            finally:
                os.unlink(temp_file.name)
                
        if not isinstance(plist, dict):
            raise CheckException(f"tool {segmentName} / {sectionName} property list root must be a dictionary", toolPath)
        return plist
    except Exception as e:
        raise CheckException(f"tool {segmentName} / {sectionName} section dump malformed (2): {str(e)}", toolPath)


def checkStep1(appPath: str) -> List[str]:
    """Checks that the app and the tool are both correctly code signed."""
    
    if not os.path.isdir(appPath):
        raise CheckException("app not found", appPath)
    
    # Check the app's code signature.
        
    checkCodeSignature(appPath, "app")
    
    # Check the tool directory.
    
    toolDirPath = os.path.join(appPath, "Contents", "Library", "LaunchServices")
    if not os.path.isdir(toolDirPath):
        raise CheckException("tool directory not found", toolDirPath)

    # Check each tool's code signature.
    
    toolPathList = []
    for toolName in os.listdir(toolDirPath):
        if toolName != ".DS_Store":
            toolPath = os.path.join(toolDirPath, toolName)
            if not os.path.isfile(toolPath):
                raise CheckException("tool directory contains a directory", toolPath)
            checkCodeSignature(toolPath, "tool")
            toolPathList.append(toolPath)

    # Check that we have at least one tool.
    
    if len(toolPathList) == 0:
        raise CheckException("no tools found", toolDirPath)

    return toolPathList


def checkStep2(appPath: str, toolPathList: List[str]) -> None:
    """Checks the SMPrivilegedExecutables entry in the app's Info.plist."""

    # Create a map from the tool name (not path) to its designated requirement.
    
    toolNameToReqMap = dict()
    for toolPath in toolPathList:
        req = readDesignatedRequirement(toolPath, "tool")
        toolNameToReqMap[os.path.basename(toolPath)] = req
    
    # Read the Info.plist for the app and extract the SMPrivilegedExecutables value.
    
    infoPath = os.path.join(appPath, "Contents", "Info.plist")
    info = readInfoPlistFromPath(infoPath)
    if "SMPrivilegedExecutables" not in info:
        raise CheckException("'SMPrivilegedExecutables' not found", infoPath)
    infoToolDict = info["SMPrivilegedExecutables"]
    if not isinstance(infoToolDict, dict):
        raise CheckException("'SMPrivilegedExecutables' must be a dictionary", infoPath)
    
    # Check that the list of tools matches the list of SMPrivilegedExecutables entries.
    
    if sorted(infoToolDict.keys()) != sorted(toolNameToReqMap.keys()):
        raise CheckException("'SMPrivilegedExecutables' and tools in 'Contents/Library/LaunchServices' don't match")
    
    # Check that all the requirements match.
    
    # This is an interesting policy choice.  Technically the tool just needs to match 
    # the requirement listed in SMPrivilegedExecutables, and we can check that by 
    # putting the requirement into tmp.req and then running
    #
    # $ codesign -v -R tmp.req /path/to/tool
    #
    # However, for a Developer ID signed tool we really want to have the SMPrivilegedExecutables 
    # entry contain the tool's designated requirement because Xcode has built a 
    # more complex DR that does lots of useful and important checks.  So, as a matter 
    # of policy we require that the value in SMPrivilegedExecutables match the tool's DR.
    
    for toolName in infoToolDict:
        if infoToolDict[toolName] != toolNameToReqMap[toolName]:
            raise CheckException(f"tool designated requirement ({toolNameToReqMap[toolName]}) doesn't match entry in 'SMPrivilegedExecutables' ({infoToolDict[toolName]})")


def checkStep3(appPath: str, toolPathList: List[str]) -> None:
    """Checks the Info.plist embedded in each helper tool."""
    
    appReq = readDesignatedRequirement(appPath, "app")
    
    for toolPath in toolPathList:
        info = readPlistFromToolSection(toolPath, "__TEXT", "__info_plist")
        if "CFBundleInfoDictionaryVersion" not in info or info["CFBundleInfoDictionaryVersion"] != "6.0":
            raise CheckException("'CFBundleInfoDictionaryVersion' in tool __TEXT / __info_plist section must be '6.0'", toolPath)
        
        if "CFBundleIdentifier" not in info or info["CFBundleIdentifier"] != os.path.basename(toolPath):
            raise CheckException("'CFBundleIdentifier' in tool __TEXT / __info_plist section must match tool name", toolPath)
        
        if "SMAuthorizedClients" not in info:
            raise CheckException("'SMAuthorizedClients' in tool __TEXT / __info_plist section not found", toolPath)
        infoClientList = info["SMAuthorizedClients"]
        if not isinstance(infoClientList, list):
            raise CheckException("'SMAuthorizedClients' in tool __TEXT / __info_plist section must be an array", toolPath)
        if len(infoClientList) != 1:
            raise CheckException("'SMAuthorizedClients' in tool __TEXT / __info_plist section must have one entry", toolPath)
            
        if infoClientList[0] != appReq:
            raise CheckException(f"app designated requirement ({appReq}) doesn't match entry in 'SMAuthorizedClients' ({infoClientList[0]})", toolPath)


def checkStep4(appPath: str, toolPathList: List[str]) -> None:
    """Checks the launchd.plist embedded in each helper tool."""
    
    for toolPath in toolPathList:
        launchd = readPlistFromToolSection(toolPath, "__TEXT", "__launchd_plist")
        if "Label" not in launchd or launchd["Label"] != os.path.basename(toolPath):
            raise CheckException("'Label' in tool __TEXT / __launchd_plist section must match tool name", toolPath)


def checkStep5(appPath: str) -> None:
    """There's nothing to do here; we effectively checked for this is steps 1 and 2."""
    pass


def check(appPath: str) -> None:
    """Checks the SMJobBless setup of the specified app."""

    # Each of the following steps matches a bullet point in the SMJobBless header doc.
    
    toolPathList = checkStep1(appPath)

    checkStep2(appPath, toolPathList)

    checkStep3(appPath, toolPathList)

    checkStep4(appPath, toolPathList)

    checkStep5(appPath)


def setreq(appPath: str, appInfoPlistPath: str, toolInfoPlistPaths: List[str]) -> None:
    """
    Reads information from the built app and uses it to set the SMJobBless setup 
    in the specified app and tool Info.plist source files.
    """
    print(f"Setting up SMJobBless for app: {appPath}")
    print(f"App Info.plist: {appInfoPlistPath}")
    print(f"Tool Info.plist paths: {toolInfoPlistPaths}")

    if not os.path.isdir(appPath):
        raise CheckException(f"app directory not found: {appPath}", appPath)

    if not os.path.isfile(appInfoPlistPath):
        raise CheckException(f"app Info.plist not found: {appInfoPlistPath}", appInfoPlistPath)
    
    for toolInfoPlistPath in toolInfoPlistPaths:
        if not os.path.isfile(toolInfoPlistPath):
            raise CheckException(f"tool Info.plist not found: {toolInfoPlistPath}", toolInfoPlistPath)

    appReq = readDesignatedRequirement(appPath, "app")
    print(f"App designated requirement: {appReq}")

    toolDirPath = os.path.join(appPath, "Contents", "Library", "LaunchServices")
    if not os.path.isdir(toolDirPath):
        raise CheckException(f"tool directory not found: {toolDirPath}", toolDirPath)
    
    toolNameToReqMap = {}
    for toolName in os.listdir(toolDirPath):
        if toolName == ".DS_Store":
            continue
        toolPath = os.path.join(toolDirPath, toolName)
        if not os.path.isfile(toolPath):
            raise CheckException(f"tool directory contains a directory: {toolPath}", toolPath)
        
        req = readDesignatedRequirement(toolPath, "tool")
        print(f"Tool {toolName} designated requirement: {req}")
        toolNameToReqMap[toolName] = req

    appToolDict = {}
    toolInfoPlistPathToToolInfoMap = {}
    for toolInfoPlistPath in toolInfoPlistPaths:
        try:
            with open(toolInfoPlistPath, 'rb') as fp:
                toolInfo = plistlib.load(fp)
            toolInfoPlistPathToToolInfoMap[toolInfoPlistPath] = toolInfo
            
            if 'CFBundleIdentifier' not in toolInfo:
                raise CheckException("'CFBundleIdentifier' not found", toolInfoPlistPath)
            bundleID = toolInfo['CFBundleIdentifier']
            if not isinstance(bundleID, str):
                raise CheckException("'CFBundleIdentifier' must be a string", toolInfoPlistPath)
            #appToolDict[bundleID] = toolNameToReqMap[os.path.basename(toolInfoPlistPath)]
            appToolDict[bundleID] = toolNameToReqMap["com.apple.bsd.SMJobBlessHelper"]
        except Exception as e:
            raise CheckException(f"Error reading tool Info.plist: {str(e)}", toolInfoPlistPath)

    try:
        with open(appInfoPlistPath, 'rb') as fp:
            appInfo = plistlib.load(fp)
        needsUpdate = 'SMPrivilegedExecutables' not in appInfo
        if not needsUpdate:
            oldAppToolDict = appInfo['SMPrivilegedExecutables']
            if not isinstance(oldAppToolDict, dict):
                raise CheckException("'SMPrivilegedExecutables' must be a dictionary", appInfoPlistPath)
            appToolDictSorted = sorted(appToolDict.items())
            oldAppToolDictSorted = sorted(oldAppToolDict.items())
            needsUpdate = appToolDictSorted != oldAppToolDictSorted
        
        if needsUpdate:
            appInfo['SMPrivilegedExecutables'] = appToolDict
            with open(appInfoPlistPath, 'wb') as fp:
                plistlib.dump(appInfo, fp)
            print(f"{appInfoPlistPath}: updated")
    except Exception as e:
        raise CheckException(f"Error updating app Info.plist: {str(e)}", appInfoPlistPath)

    toolAppListSorted = [appReq]  # only one element, so obviously sorted
    for toolInfoPlistPath in toolInfoPlistPaths:
        try:
            with open(toolInfoPlistPath, 'rb') as fp:
                toolInfo = plistlib.load(fp)
            
            needsUpdate = 'SMAuthorizedClients' not in toolInfo
            if not needsUpdate:
                oldToolAppList = toolInfo['SMAuthorizedClients']
                if not isinstance(oldToolAppList, list):
                    raise CheckException("'SMAuthorizedClients' must be an array", toolInfoPlistPath)
                oldToolAppListSorted = sorted(oldToolAppList)
                needsUpdate = toolAppListSorted != oldToolAppListSorted
            
            if needsUpdate:
                toolInfo['SMAuthorizedClients'] = toolAppListSorted
                with open(toolInfoPlistPath, 'wb') as fp:
                    plistlib.dump(toolInfo, fp)
                print(f"{toolInfoPlistPath}: updated")
        except Exception as e:
            raise CheckException(f"Error updating tool Info.plist: {str(e)}", toolInfoPlistPath)


def main() -> None:
    options, appArgs = getopt.getopt(sys.argv[1:], "d")
    
    debug = False
    for opt, val in options:
        if opt == "-d":
            debug = True
        else:
            raise UsageException()

    if len(appArgs) == 0:
        raise UsageException()
    command = appArgs[0]
    if command == "check":
        if len(appArgs) != 2:
            raise UsageException()
        check(appArgs[1])
    elif command == "setreq":
        if len(appArgs) < 4:
            raise UsageException()
        setreq(appArgs[1], appArgs[2], appArgs[3:])
    else:
        raise UsageException()


if __name__ == "__main__":
    try:
        main()
    except CheckException as e:
        if e.path is None:
            print(f"{os.path.basename(sys.argv[0])}: {e.message}", file=sys.stderr)
        else:
            path = e.path
            if path.endswith("/"):
                path = path[:-1]
            print(f"{path}: {e.message}", file=sys.stderr)
        sys.exit(1)
    except UsageException as e:
        print(f"usage: {os.path.basename(sys.argv[0])} check  /path/to/app", file=sys.stderr)
        print(f"       {os.path.basename(sys.argv[0])} setreq /path/to/app /path/to/app/Info.plist /path/to/tool/Info.plist...", file=sys.stderr)
        sys.exit(1)
