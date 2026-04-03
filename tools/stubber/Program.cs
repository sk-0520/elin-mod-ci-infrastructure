using System;
using System.Linq;
using System.IO;
using Mono.Cecil;
using Mono.Cecil.Cil;

class Program
{
    static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            throw new ArgumentException("No assembly paths provided.");
        }

        foreach (var path in args)
        {
            Console.WriteLine($"Processing: {path}");
            var resolver = new DefaultAssemblyResolver();
            var asmDir = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(asmDir))
            {
                resolver.AddSearchDirectory(asmDir);
            }
            resolver.AddSearchDirectory(Directory.GetCurrentDirectory());

            var readerParams = new ReaderParameters
            {
                ReadWrite = false,
                AssemblyResolver = resolver
            };
            var asm = AssemblyDefinition.ReadAssembly(path, readerParams);
            var module = asm.MainModule;
            var notImplCtor = module.ImportReference(typeof(NotImplementedException).GetConstructor(Type.EmptyTypes));

            foreach (var type in module.Types)
            {
                ProcessType(type, module, notImplCtor);
            }

            var outPath = path + ".stub";
            asm.Write(outPath);
        }

        return 0;
    }

    static void ProcessType(TypeDefinition type, ModuleDefinition module, MethodReference notImplCtor)
    {
        foreach (var method in type.Methods.Where(m => m.HasBody && !m.IsAbstract && !m.IsPInvokeImpl))
        {
            // プロパティの getter/setter は一切変更しない
            if (method.IsSpecialName && (method.Name.StartsWith("get_") || method.Name.StartsWith("set_")))
            {
                continue;
            }

            method.Body.Instructions.Clear();
            var il = method.Body.GetILProcessor();

            // 静的コンストラクタ (.cctor) は何もしない
            if (method.IsConstructor && method.IsStatic)
            {
                il.Emit(OpCodes.Ret);
            }
            else
            {
                il.Emit(OpCodes.Newobj, notImplCtor);
                il.Emit(OpCodes.Throw);
            }
        }

        foreach (var nested in type.NestedTypes)
        {
            ProcessType(nested, module, notImplCtor);
        }
    }
}
