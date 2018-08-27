module TurnTable
using Printf
using Compat, PyCall


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
function open(serialport::SerialPort)
    serialport.python_ptr[:open]()
    return serialport
end
function close(serialport::SerialPort)
    serialport.python_ptr[:close]()
    return serialport
end
function write(serialport::SerialPort, data::@compat UInt8)
    serialport.python_ptr[:write](data)
end
function write(serialport::SerialPort, data::SerialString)
    serialport.python_ptr[:write](data)
end
function read(ser::SerialPort, bytes::Integer)
    ser.python_ptr[:read](bytes)
end






"""
List available serialports on the system.
"""
function list_serialports()
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
device() = list_serialports()
    



function setorigin(id; baudrate = 19200)
    s = SerialPort(id, baudrate)
    write(s, "Get BaudRate" * string(Char(13)))
    fb = read(s, 6)
    info("baudrate: $fb")

    # disable analog input to prevent noise input (must)
    write(s, "Set AnalogInput OFF " * string(Char(13)))
    fb = read(s, 3)
    write(s, "Set PulseInput OFF " * string(Char(13)))
    fb = read(s, 3)
    write(s, "Set Torque 70.0 " * string(Char(13)))
    fb = read(s, 3)
    write(s, "Set SmartTorque ON " * string(Char(13)))
    fb = read(s, 3)
    write(s, "Set Velocity 2.00 " * string(Char(13)))
    fb = read(s, 3)
    write(s, "Set Origin " * string(Char(13)))
    fb = read(s, 3)

    close(s)
    return fb
end



function rotate(id, degree; direction="CCW", baudrate=19200)
    d = @sprintf("%3.1f", degree)
    for i = 1:5-length(d)
        d = "0" * d
    end
    s = SerialPort(id, baudrate)
    write(s, "GoTo " * direction * " +" * d * " " * string(Char(13)))
    fb = read(s, 3)
    close(s)
    return fb
end




end # module
