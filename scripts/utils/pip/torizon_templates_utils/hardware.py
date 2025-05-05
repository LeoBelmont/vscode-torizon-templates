def get_gpu_vendor(model: str, rc_prefix: bool = False):
    model = model.lower()

    if "am62" in model:
        return "am62"
    elif "beagleplay" in model:
        return "am62"
    elif "imx8" in model:
        return "-imx8" if rc_prefix else "-vivante"
    else:
        # generic non gpu specific
        return ""