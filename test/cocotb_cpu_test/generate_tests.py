import gen_loads
import gen_alu
import gen_inc_dec
import gen_cb

def main():
    gen_loads.generate()
    gen_alu.generate()
    gen_inc_dec.generate()
    gen_cb.generate()
    print("All tests generated successfully!")

if __name__ == "__main__":
    main()
