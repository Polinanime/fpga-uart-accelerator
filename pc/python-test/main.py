import time
import serial
import struct

VALID_OP = ["+", "-"]#, "*", "/", ">", "<", "="]
SYMB_START = "<".encode("utf-8")
SYMB_DELIM_A = "|".encode("utf-8")
SYMB_DELIM_B = "/".encode("utf-8")
SYMB_END   = ">".encode("utf-8")
FORMAT = "<f"

# configure the serial connections (the parameters differs on the device you are connecting to)
ser = serial.Serial(
    port='/dev/ttyUSB0',
    baudrate=115200,
    parity="N",
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS
)

def verify_input(a: float, b: float, op: str) -> bool:
    return op in VALID_OP

def input_data() -> tuple:
    is_ok = False

    while not is_ok: 
        try:
            a = float(input("a: "))
            b = float(input("b: "))
            op = input(f"op {tuple(VALID_OP)}: ")
            is_ok = True
        except Exception:
            print("Invalid input!")
    return (a, b, op)

def float2bytes(f: float) -> str:
    bin_bytes = struct.pack(FORMAT, f)
    # bin_str = "".join(f"{byte:08b}" for byte in bin_bytes)
    return bin_bytes

def bytes2ascii(s: str) -> list:
    ascii_symbs = [chr(byte) for byte in s]
    return ascii_symbs

def float2ascii(f: float) -> list:
    bytes = float2bytes(f)
    ascii = bytes2ascii(bytes)
    return ascii 

def main():
    global FORMAT

    a, b, op = input_data()

    if op == "+":
        FORMAT = ">I"
        a = int(a)
        b = int(b)

    # Prepare data for Uart
    bytes_a = float2bytes(a)
    bytes_b = float2bytes(b)
    bytes_op = op.encode("utf-8")

    # Write into UART:
    ser.write(SYMB_START)
    ser.write(bytes_op)
    ser.write(SYMB_DELIM_A)
    ser.write(bytes_a)
    ser.write(SYMB_DELIM_B)
    ser.write(bytes_b)
    ser.write(SYMB_END)

    bytes_res = ser.read_until(size=6)
    print("Raw data: ", [chr(i) for i in bytes_res])

    try: 
        res = struct.unpack(FORMAT, bytes_res[1:5])[0]
        print(f"Result: {res}")
    except Exception:
        pass


if __name__ == "__main__":
    main()