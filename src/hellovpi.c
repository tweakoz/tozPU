# include  <vpi_user.h>

static int hello_compiletf(char*user_data)
{
      return 0;
}

static int hello_calltf(char*user_data)
{
	vpiHandle systfref, args_iter, argh;
	struct t_vpi_value argval;
	int intval;
	const char* strval; 
	// Obtain a handle to the argument list
	systfref = vpi_handle(vpiSysTfCall, NULL);
	args_iter = vpi_iterate(vpiArgument, systfref);
	 
	// Grab the value of the first argument
	argh = vpi_scan(args_iter);
	argval.format = vpiStringVal;
	vpi_get_value(argh, &argval);
	strval = argval.value.integer;

	argval.format = vpiIntVal;
	vpi_get_value(argh, &argval);
	intval = argval.value.integer;
	
	vpi_printf("VPI routine received <%s:%d>\n", strval, intval);
	return 0;
}

void hello_register()
{
      s_vpi_systf_data tf_data;

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$hello";
      tf_data.calltf    = hello_calltf;
      tf_data.compiletf = hello_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);
}

void (*vlog_startup_routines[])() = {
    hello_register,
    0
};

