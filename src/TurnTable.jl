module TurnTable
using Printf
using PyCall
using Libaudio


const PySerial = PyCall.PyNULL()
const PySerialListPorts = PyCall.PyNULL()
const SerialString = String


struct SerialPort <: IO
    port::SerialString
    baudrate::Int
    bytesize::Int
    parity::SerialString
    stopbits::Int
    timeout
    xonxoff::Bool
    rtscts::Bool
    dsrdtr::Bool
    python_ptr::PyObject
end

function __init__()
    copy!(PySerial, pyimport_conda("serial", "pyserial"))
    copy!(PySerialListPorts, pyimport("serial.tools.list_ports"))
end


function serialport(port, baudrate)
    py_ptr = PySerial[:Serial](port, baudrate)
    SerialPort(port,
               baudrate,
               py_ptr[:bytesize],
               py_ptr[:parity],
               py_ptr[:stopbits],
               py_ptr[:timeout],
               py_ptr[:xonxoff],
               py_ptr[:rtscts],
               py_ptr[:dsrdtr], py_ptr)
end




@static if VERSION >= v"0.5"
   function (::Type{SerialPort})(port, baudrate)
       serialport(port, baudrate)
   end
end
# serialport.python_ptr[:open]()









"""
List available serialports on the system.
"""
function listserialports()
    @static if Sys.isunix()
        ports = readdir("/dev/")
        f = is_apple() ? _valid_darwin_port : _valid_linux_port
        filter!(f, ports)
        return [string("/dev/", port) for port in ports]
    end
    @static if Sys.iswindows()
        [i[1] for i in collect(PySerialListPorts[:comports]())]
    end
end

    



function setorigin(id; baudrate = 19200)
    s = SerialPort(id, baudrate)
    s.python_ptr[:write](b"Get BaudRate\r")
    y = s.python_ptr[:read](6)

    root = joinpath(Libaudio.folder(), Libaudio.logfile())
    Libaudio.printl(root, :blink, Libaudio.nows() * " | TurnTable.setorigin: baudrate = $(y) bps")

    # disable analog input to prevent noise input (must)
    s.python_ptr[:write](b"Set AnalogInput OFF \r")
    y = s.python_ptr[:read](3)
    s.python_ptr[:write](b"Set PulseInput OFF \r")
    y = s.python_ptr[:read](3)
    s.python_ptr[:write](b"Set Torque 70.0 \r")
    y = s.python_ptr[:read](3)
    s.python_ptr[:write](b"Set SmartTorque ON \r")
    y = s.python_ptr[:read](3)
    s.python_ptr[:write](b"Set Velocity 2.00 \r")
    y = s.python_ptr[:read](3)
    s.python_ptr[:write](b"Set Origin \r")
    y = s.python_ptr[:read](3)
    s.python_ptr[:close]()
    Libaudio.printl(root, :blink, Libaudio.nows() * " | TurnTable.setorigin: set current position as origin")
    return y
end



function rotate(id, degree; direction="CCW", baudrate=19200)
    d = @sprintf("%3.1f", degree)
    for i = 1:5-length(d)
        d = "0" * d
    end
    s = SerialPort(id, baudrate)
    s.python_ptr[:write](Vector{UInt8}("GoTo " * direction * " +" * d * " \r"))
    y = s.python_ptr[:read](3)
    s.python_ptr[:close]()

    root = joinpath(Libaudio.folder(), Libaudio.logfile())
    Libaudio.printl(root, :blink, Libaudio.nows() * " | TurnTable.rotate: moved to degree $(degree) $(direction)")
    return y
end




end # module
