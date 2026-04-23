from vitis import *
import inspect
client = create_client()
client.set_workspace(path='D:/workspace/zynq_pov/02_hello_zynq/vitis_ws')
plat = client.get_component(name='hello_plat')
domain = plat.get_domain(name='standalone_ps7_cortexa9_0')

# Check signature
print("set_lib signature:", inspect.signature(domain.set_lib))

# Try positional
try:
    domain.set_lib('lwip220')
except Exception as e:
    print(f"positional failed: {e}")
    # Try other kw args
    try:
        domain.set_lib(lib_name='lwip220')
    except Exception as e2:
        print(f"lib_name failed: {e2}")

print("After:", domain.get_libs())

# Regenerate and build
print("Regenerating...")
domain.regenerate()
print("Building...")
plat.build()
print("Done.")
