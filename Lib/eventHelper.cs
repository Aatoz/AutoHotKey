using System;
using System.Reflection;
using System.Reflection.Emit;
using System.Runtime.InteropServices;

public class EventHelper {
    // Delegate type for the AutoHotkey callback.
    public delegate void CallbackType([MarshalAs(UnmanagedType.SafeArray)] object[] argv);
    // AddHandler: Adds a callback as a handler for the given event of the given object.
    public void AddHandler(object target, string eventName, string pcb) {
        var cb = ParseCB(pcb);
        // Reference: http://msdn.microsoft.com/en-us/library/ms228976
        EventInfo evt = target.GetType().GetEvent(eventName);
        Type handlerType = evt.EventHandlerType;
        MethodInfo handlerSig = handlerType.GetMethod("Invoke");
        ParameterInfo[] parameters = handlerSig.GetParameters();
        Type[] parameterTypes = new Type[parameters.Length+1];
        parameterTypes[0] = typeof(CallbackType);
        for (int i = 0; i < parameters.Length; i++)
            parameterTypes[i+1] = parameters[i].ParameterType;
        
        var handler = new DynamicMethod("", handlerSig.ReturnType, parameterTypes, true);
        
        var il = handler.GetILGenerator();
        var loc = il.DeclareLocal(typeof(object[]));
        il.Emit(OpCodes.Ldc_I4_2);
        il.Emit(OpCodes.Newarr, typeof(object));
        il.Emit(OpCodes.Stloc_0);
        
        il.Emit(OpCodes.Ldloc_0);
        il.Emit(OpCodes.Ldc_I4_0);
        il.Emit(OpCodes.Ldarg_1);
        il.Emit(OpCodes.Stelem_Ref); 
        
        il.Emit(OpCodes.Ldloc_0);
        il.Emit(OpCodes.Ldc_I4_1);
        il.Emit(OpCodes.Ldarg_2);
        il.Emit(OpCodes.Stelem_Ref);
        
        il.Emit(OpCodes.Ldarg_0);
        il.Emit(OpCodes.Ldloc_0);
        il.Emit(OpCodes.Call, typeof(CallbackType).GetMethod("Invoke"));
        il.Emit(OpCodes.Ret);
        
        var delg = handler.CreateDelegate(handlerType, cb);
        var adder = evt.GetAddMethod();
        adder.Invoke(target, new object[] { delg });
    }
    // Much simpler method, restricted to a specific delegate type.
    public EventHandler MakeHandler(string pcb) {
        var cb = ParseCB(pcb);
        return (sender, e) => cb(new object[]{ sender, e });
    }
    public CallbackType ParseCB(string cb) {
        // For 32-bit, simply marking the parameter of AddHandler/MakeHandler with:
        //   [MarshalAs(UnmanagedType.FunctionPtr)] CallbackType cb
        // is adequate, but since IDispatch doesn't support 64-bit integers,
        // we have to pass the callback address as a string for x64 builds.
        return (CallbackType) Marshal.GetDelegateForFunctionPointer(
            (IntPtr)Int64.Parse(cb), typeof(CallbackType));
    }
}