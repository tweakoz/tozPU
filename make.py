#!/usr/bin/python
import os
import platform
import os.path

def spawner( cmdline ):
        os.system( cmdline )

spawner( "iverilog -o vvp/tweakpu.vvp src/tweakpu.v" );
spawner( "vvp vvp/tweakpu.vvp" );
spawner( "gtkwave tweakpu.vcd tweakoz_gtkwave.sav" );

