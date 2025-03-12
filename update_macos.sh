#!/bin/bash

cd macos
rm -f Podfile.lock
pod install
cd ..
