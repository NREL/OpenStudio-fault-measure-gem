#This ruby script creates multiple double arguments for the OpenStudio
#user to enter coefficients of certain models defined as a1,...,an

#define function to get parameters from users
def enter_coefficients(args, num=0, model_name="", default_values=[], descriptor_str="")

  #args is an OpenStudio::Ruleset::OSArgumentVector object that
  #defines the input to the measure script
  
  #num is an integer for the number of arguments the measure script demands from
  #the user
  
  #model_name is a string for the name of the model. It is used for the DisplayName
  #and the variable name in the argument
  
  #default_value is an array for the default values of the parameters
  #if it is not configured, it is defined as zero
  
  #descriptor_str are information your want to add at the Display Name
  
  #insert value to default value
  if default_values.length < num
    init_num = default_values.length
    for ii in init_num..num
      default_values << 0
    end
  end
  
  #add arguments
  for ii in 1..num
    para = OpenStudio::Ruleset::OSArgument::makeDoubleArgument(model_name+"a#{ii}", false)
    para.setDisplayName("Parameter a#{ii} for the "+model_name+" model"+descriptor_str)
    para.setDefaultValue(default_values[ii-1])  #default fouling level to be 30%
    args << para
  end

  return args
end

#define function to pass parameters from user_arguments in the run function
def runner_pass_coefficients(runner, user_arguments, num=0, model_name)

  #runner and user_arguments are the inputs to the run function in the measure script
  
  #num is an integer for the number of arguments the measure script demands from
  #the user
  
  #model_name is a string for the name of the model. It is used for the DisplayName
  #and the variable name in the argument
  
  coeff = []
    
  #add arguments
  for ii in 1..num
    coeff << runner.getDoubleArgumentValue(model_name+"a#{ii}",user_arguments)
  end

  return coeff  #return an array of coefficients
end