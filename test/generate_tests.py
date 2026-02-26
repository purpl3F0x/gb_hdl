import gen_loads
import gen_alu
import gen_inc_dec

def main():
    gen_loads.generate()
    gen_alu.generate()
    gen_inc_dec.generate()
    print("All tests generated successfully!")

if __name__ == "__main__":
    main()
