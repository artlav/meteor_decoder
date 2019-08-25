#!/bin/sh
mkdir units 2>/dev/null
rm units/* 2>/dev/null
fpc -CX -XX -O3 -Mdelphi -FUunits -Fualib medet.dpr
