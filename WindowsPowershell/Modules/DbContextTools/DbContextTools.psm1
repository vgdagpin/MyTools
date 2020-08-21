Function Generate-DbContext {
    param(
        [string]$EntitiesPath
    )

	#$entitiesPath = "D:\Git Workspace\Crux\Crux.Domain\Entities"
	#CD $entitiesPath

	$entitiesPath = if([string]::IsNullOrWhiteSpace($EntitiesPath)) { (Resolve-Path .\).Path } else { $EntitiesPath }

	$config = Get-ChildItem -Filter "_config.json" | Get-Content | ConvertFrom-Json
	$entities = Get-ChildItem -Filter "*.cs" -Recurse

	if (!(Test-Path $config.IDbContext.Path))
	{
		New-Item -ItemType Directory -Force -Path $config.IDbContext.Path | Out-Null
	}
		
	if (!(Test-Path $config.DbContext.Path))
	{
		New-Item -ItemType Directory -Force -Path $config.DbContext.Path | Out-Null
	}

	if (!(Test-Path "$($config.DbContext.Path)/Configurations"))
	{
		New-Item -ItemType Directory -Force -Path "$($config.DbContext.Path)/Configurations" | Out-Null
	}
		
	$iDest = Join-Path "$($entitiesPath)" "$($config.IDbContext.Path)" -Resolve
	$cDest = Join-Path "$($entitiesPath)" "$($config.DbContext.Path)" -Resolve
	$confDest = Join-Path "$($entitiesPath)" "$($config.DbContext.Path)/Configurations" -Resolve


	$arrUsing = [System.Collections.ArrayList]@()

	Function Pluralize($str) 
	{
		$temp = $str
		
		if ($temp -like "*sis")
		{
			return "$($temp.SubString(0, $temp.Length - 3))ses";
		}

		if ($temp -like "*s")
		{
			return "$($temp)es";
		}

		if ($temp -like "*ay")
		{
			return "$($temp)s";
		}

		if ($temp -like "*y")
		{
			return "$($temp.SubString(0, $temp.Length - 1))ies";
		}
		
		

		return "$($temp)s";
	}

	Function GetNamespace($entity)
	{
		$entityPath = $entity.DirectoryName

		$t = $entityPath.Replace($entitiesPath, "");

		$t2 = "$($($config.EntitiesNamespace))$t" -replace '\\', '.'

		return $t2
	}

	Function TrackUsing($entity)
	{
		$ns = GetNamespace $entity

		if ($arrUsing.Contains($ns) -eq $false)
		{
			$arrUsing.Add($ns) | Out-Null
		}
	}

	Function FormatEntityType($entity)
	{
		$ns = GetNamespace $entity

		return "$($ns).$($entity.BaseName)"
	}




	foreach($entity in $entities)
	{
		TrackUsing $entity
	}



	$addlUsing = "using $($arrUsing -join ';
using ');";


	$iContent = "
$($addlUsing)
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Infrastructure;
using System;
using System.Diagnostics.CodeAnalysis;
using System.Threading;
using System.Threading.Tasks;

namespace $($config.IDbContext.Namespace)
{
	public interface $($config.IDbContext.Name)
	{
		#region Entities
$(
	foreach($entity in $entities)
	{
"        
		DbSet<$($entity.BaseName)> $("$(Pluralize $entity.BaseName)") { get; set; }"  
	}
)
		#endregion

		
		EntityEntry<TEntity> Entry<TEntity>([NotNull] TEntity entity) where TEntity : class;
		
		//EntityEntry Entry([NotNull] object entity);
		//DatabaseFacade Database { get; }        
	}
}
	";

	$cContent = "
$($addlUsing)
using $($config.IDbContext.Namespace);
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using System;
using System.Threading;
using System.Threading.Tasks;
using System.Reflection;
using System.Linq;

namespace $($config.DbContext.Namespace)
{
	public class $($config.DbContext.Name) : DbContext, $($config.IDbContext.Name)
	{
		#region Entities
$(
	foreach($entity in $entities)
	{
"
		public DbSet<$($entity.BaseName)> $("$(Pluralize $entity.BaseName)") {get;set;}"
	}
)
		#endregion


		public $($config.DbContext.Name)(DbContextOptions<$($config.DbContext.Name)> dbContextOpt) : base(dbContextOpt)
		{

		}
		
		protected override void OnModelCreating(ModelBuilder modelBuilder)
		{
			modelBuilder.ApplyConfigurationsFromAssembly(Assembly.GetExecutingAssembly());
		}
	}
}
	";




	Function GenerateConfigurationFile($entity)
	{
		$ns = GetNamespace $entity

		$confContent = "
using $($ns);
using System;
using System.Collections.Generic;
using System.Text;

namespace $($config.DbContext.Namespace).Configurations
{
	public class $($entity.BaseName)_Configuration : BaseConfiguration<$($entity.BaseName)>
	{
		public override void ConfigureProperty(BasePropertyBuilder<$($entity.BaseName)> builder)
		{

		}
	}
}
";

		$configFile = "$($entity.BaseName)_Configuration.cs";

		if (!(Test-Path "$($confDest)/$($configFile)"))
		{
			New-Item -Path $confDest -Name "$($entity.BaseName)_Configuration.cs" -ItemType "File" -Value $confContent.Trim() -Force | Out-Null
		}    
	}

	foreach($entity in $entities)
	{
		GenerateConfigurationFile $entity
	}

	New-Item -Path $cDest -Name "$($config.DbContext.Name).cs" -ItemType "File" -Value $cContent.Trim() -Force | Out-Null
	New-Item -Path $iDest -Name "$($config.IDbContext.Name).cs" -ItemType "File" -Value $iContent.Trim() -Force | Out-Null
}