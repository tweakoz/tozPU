#!/usr/bin/python
import os
import platform
import os.path

def spawner( cmdline ):
        os.system( cmdline )

spawner( "iverilog src/tweakpu.v" );
spawner( "vvp a.out" );
spawner( "gtkwave tweakpu.vcd tweakoz_gtkwave.sav" );

